# app/models/concerns/symmetric_encryption.rb
#
# Rails 6.1 does NOT ship ActiveRecord::Encryption (`encrypts :api_key`) —
# that landed in Rails 7. This concern provides equivalent at-rest encryption
# for a single column using ActiveSupport::MessageEncryptor.
#
# Key source: `ENV['AI_KEY_ENCRYPTION_KEY']` if set (32-byte hex preferred),
# otherwise we derive a 32-byte key from `Rails.application.secret_key_base`
# via ActiveSupport::KeyGenerator with a fixed salt. This is the same
# strategy Rails 7's ActiveRecord::Encryption uses internally when no
# explicit key is configured.
#
# Usage:
#
#   class AiProviderConfig < ApplicationRecord
#     include SymmetricEncryption
#     symmetric_encrypts :api_key, ciphertext_column: :api_key_ciphertext
#   end
#
#   record.api_key = 'sk-...'   # → writes to api_key_ciphertext (encrypted)
#   record.api_key              # → decrypts api_key_ciphertext
#
# Notes:
# - Returns nil if the ciphertext column is blank or decryption fails
#   (e.g. key rotation / corrupted row). We swallow decryption errors so a
#   single bad row doesn't crash the whole providers#index response.
# - The plaintext is never persisted; we only memoize the most recently
#   assigned value in an ivar so `record.api_key` immediately after a
#   setter call returns what you'd expect even before save.

module SymmetricEncryption
  extend ActiveSupport::Concern

  ENCRYPTION_SALT = 'f13-explorer/ai-provider-config/v1'.freeze

  class_methods do
    def symmetric_encrypts(attr, ciphertext_column:)
      ivar = "@_symmetric_#{attr}"

      define_method(attr) do
        return instance_variable_get(ivar) if instance_variable_defined?(ivar)
        cipher = send(ciphertext_column)
        return nil if cipher.blank?
        begin
          SymmetricEncryption._encryptor.decrypt_and_verify(cipher)
        rescue ActiveSupport::MessageEncryptor::InvalidMessage,
               ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end
      end

      define_method("#{attr}=") do |value|
        instance_variable_set(ivar, value)
        if value.blank?
          send("#{ciphertext_column}=", nil)
        else
          send("#{ciphertext_column}=", SymmetricEncryption._encryptor.encrypt_and_sign(value.to_s))
        end
      end
    end
  end

  # 32-byte key derived once per process. Memoized on the module.
  def self._encryptor
    @_encryptor ||= begin
      raw = ENV['AI_KEY_ENCRYPTION_KEY']
      key = if raw.present?
              # Accept hex or raw; pad/truncate to 32 bytes.
              decoded = raw.match?(/\A[0-9a-fA-F]+\z/) ? [raw].pack('H*') : raw.dup
              decoded.byteslice(0, 32).ljust(32, "\0")
            else
              base = Rails.application.secret_key_base.to_s
              raise 'secret_key_base is not set; cannot derive AI encryption key' if base.empty?
              ActiveSupport::KeyGenerator.new(base).generate_key(ENCRYPTION_SALT, 32)
            end
      ActiveSupport::MessageEncryptor.new(key, cipher: 'aes-256-gcm')
    end
  end
end
