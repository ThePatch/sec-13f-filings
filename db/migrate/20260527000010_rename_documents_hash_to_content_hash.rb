# The documents table was originally migrated with a `hash` column for content
# deduplication. `Object#hash` exists in Ruby with the contract "returns an
# Integer" — ActiveRecord uses it internally inside transaction commit tracking
# (Set membership). When AR's Document#hash returned the column's String value
# the post-commit hook crashed with `no implicit conversion of String into
# Integer`. Renaming to content_hash fixes it without altering semantics.
class RenameDocumentsHashToContentHash < ActiveRecord::Migration[6.1]
  def up
    execute "ALTER INDEX IF EXISTS documents_hash RENAME TO documents_content_hash"
    rename_column :documents, :hash, :content_hash
  end

  def down
    rename_column :documents, :content_hash, :hash
    execute "ALTER INDEX IF EXISTS documents_content_hash RENAME TO documents_hash"
  end
end
