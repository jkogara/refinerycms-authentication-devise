# frozen_string_literal: true

require 'devise'
require 'friendly_id'

module Refinery
  module Authentication
    module Devise
      class User < Refinery::Core::BaseModel
        extend FriendlyId

        has_many :roles_users, class_name: 'Refinery::Authentication::Devise::RolesUsers'
        has_many :roles, through: :roles_users, class_name: 'Refinery::Authentication::Devise::Role'

        has_many :plugins, -> { order('position ASC') },
                 class_name: 'Refinery::Authentication::Devise::UserPlugin', dependent: :destroy

        friendly_id :username, use: [:slugged]

        # Include default devise modules. Others available are:
        # :token_authenticatable, :confirmable, :lockable and :timeoutable
        if respond_to?(:devise)
          devise :database_authenticatable, :registerable, :recoverable, :rememberable,
                 :trackable, :validatable, authentication_keys: [:login]
        end

        # Setup accessible (or protected) attributes for your model
        # :login is a virtual attribute for authenticating by either username or email
        # This is in addition to a real persisted field like 'username'
        attr_accessor :login

        validates :username, presence: true, uniqueness: true
        before_validation :downcase_username, :strip_username

        class << self
          # Find user by email or username.
          # https://github.com/plataformatec/devise/wiki/How-To:-Allow-users-to-sign_in-using-their-username-or-email-address
          def find_for_database_authentication(conditions)
            value = conditions[authentication_keys.first]
            where(['username = :value OR email = :value', { value: value }]).first
          end

          def find_or_initialize_with_error_by_reset_password_token(original_token)
            find_or_initialize_with_error_by :reset_password_token,
                                             ::Devise.token_generator.digest(self, :reset_password_token, original_token)
          end
        end

        # Call devise reset function, taken from
        # https://github.com/plataformatec/devise/blob/v3.2.4/lib/devise/models/recoverable.rb#L45-L56
        def generate_reset_password_token!
          raw, enc = ::Devise.token_generator.generate(self.class, :reset_password_token)
          update(
            reset_password_token: enc,
            reset_password_sent_at: Time.now.utc
          )
          raw
        end

        def plugins=(plugin_names)
          return :can_not_set_plugins_when_not_persisted unless persisted?

          filtered_names = filter_existing_plugins_for(string_plugin_names(plugin_names))
          create_plugins_for(filtered_names)
        end

        def active_plugins
          @active_plugins ||= Refinery::Plugins.new(
            Refinery::Plugins.registered.select do |plugin|
              has_role?(:superuser) || authorised_plugins.include?(plugin.name)
            end
          )
        end

        def has_plugin?(name)
          active_plugins.names.include?(name)
        end

        def authorised_plugins
          plugins.collect(&:name) | ::Refinery::Plugins.always_allowed.names
        end
        alias authorized_plugins authorised_plugins

        # Returns a URL to the first plugin with a URL in the menu. Used for
        # admin user's root admin url.
        # See Refinery::Core::NilUser#landing_url.
        def landing_url
          active_plugins.in_menu.first_url_in_menu
        end

        def can_delete?(user_to_delete = self)
          user_to_delete.persisted? &&
            !user_to_delete.has_role?(:superuser) &&
            ::Refinery::Authentication::Devise::Role[:refinery].users.any? &&
            id != user_to_delete.id
        end

        def can_edit?(user_to_edit = self)
          user_to_edit.persisted? && (user_to_edit == self || has_role?(:superuser))
        end

        def add_role(title)
          raise ::ArgumentError, 'Role should be the title of the role not a role object.' if title.is_a?(::Refinery::Authentication::Devise::Role)

          roles << ::Refinery::Authentication::Devise::Role[title] unless has_role?(title)
        end

        def has_role?(title)
          raise ::ArgumentError, 'Role should be the title of the role not a role object.' if title.is_a?(::Refinery::Authentication::Devise::Role)

          roles.any? { |r| r.title == title.to_s.camelize }
        end

        def create_first
          if valid?
            # first we need to save user
            save
            # add refinery role
            add_role(:refinery)
            # add superuser role if there are no other users
            add_role(:superuser) if ::Refinery::Authentication::Devise::Role[:refinery].users.count == 1
            # add plugins
            self.plugins = Refinery::Plugins.registered.in_menu.names
          end

          # return true/false based on validations
          valid?
        end

        def to_s
          (full_name.presence || username).to_s
        end

        private

        # To ensure uniqueness without case sensitivity we first downcase the username.
        # We do this here and not in SQL is that it will otherwise bypass indexes using LOWER:
        # SELECT 1 FROM "refinery_users" WHERE LOWER("refinery_users"."username") = LOWER('UsErNAME') LIMIT 1
        def downcase_username
          self.username = username.downcase if username?
        end

        # To ensure that we aren't creating "admin" and "admin " as the same thing.
        # Also ensures that "admin user" and "admin    user" are the same thing.
        def strip_username
          self.username = username.strip.gsub(/\ {2,}/, ' ') if username?
        end

        def string_plugin_names(plugin_names)
          plugin_names.select { |plugin_name| plugin_name.is_a?(String) }
        end

        def create_plugins_for(plugin_names)
          plugin_names.each { |plugin_name| plugins.create name: plugin_name, position: plugin_position }
        end

        def plugin_position
          plugins.select(:position).map { |p| p.position.to_i }.max.to_i + 1
        end

        def filter_existing_plugins_for(plugin_names)
          assigned_plugins = plugins.load
          assigned_plugins.each do |assigned_plugin|
            if plugin_names.include?(assigned_plugin.name)
              plugin_names.delete(assigned_plugin.name)
            else
              assigned_plugin.destroy
            end
          end
          plugin_names
        end
      end
    end
  end
end
