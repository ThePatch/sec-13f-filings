# app/models/ai_provider_config.rb
#
# Rails 6.1 lacks ActiveRecord::Encryption (`encrypts :api_key`), so we use
# the SymmetricEncryption concern (AES-256-GCM via MessageEncryptor) to
# read/write `api_key_ciphertext`. See concerns/symmetric_encryption.rb
# for the key-derivation strategy.

class AiProviderConfig < ApplicationRecord
  include SymmetricEncryption

  PROVIDERS = %w[claude openai groq openrouter nim ollama].freeze

  validates :session_id, presence: true
  validates :provider,   presence: true, inclusion: { in: PROVIDERS }
  validates :provider,   uniqueness: { scope: :session_id }

  symmetric_encrypts :api_key, ciphertext_column: :api_key_ciphertext

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end
end
