# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_30_110000) do
  create_table "account_types", force: :cascade do |t|
    t.string "code"
    t.string "role"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_account_types_on_code", unique: true
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name"
    t.integer "due_day"
    t.integer "closing_day"
    t.integer "account_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.decimal "balance", precision: 10, scale: 2, default: "0.0", null: false
    t.index ["account_type_id"], name: "index_accounts_on_account_type_id"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "category_type", default: 1, null: false
    t.text "description"
    t.index ["category_type"], name: "index_categories_on_category_type"
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "credit_statements", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "month", null: false
    t.decimal "amount_due", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "amount_paid", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.date "closed_on"
    t.date "due_on"
    t.date "paid_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "month"], name: "index_credit_statements_on_account_id_and_month", unique: true
    t.index ["account_id"], name: "index_credit_statements_on_account_id"
  end

  create_table "entries", force: :cascade do |t|
    t.integer "transaction_id", null: false
    t.integer "account_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "entry_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "entry_type"], name: "index_entries_on_account_and_type"
    t.index ["account_id"], name: "index_entries_on_account_id"
    t.index ["transaction_id", "account_id"], name: "index_entries_on_transaction_id_and_account_id"
    t.index ["transaction_id"], name: "index_entries_on_transaction_id"
  end

  create_table "import_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "source_type", null: false
    t.string "original_filename"
    t.string "account_type"
    t.integer "account_id", null: false
    t.text "raw_file"
    t.json "metadata"
    t.datetime "imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "file_digest"
    t.index ["account_id", "file_digest"], name: "index_import_sessions_on_account_id_and_file_digest", unique: true
    t.index ["user_id"], name: "index_import_sessions_on_user_id"
  end

  create_table "imported_transactions", force: :cascade do |t|
    t.integer "import_session_id", null: false
    t.integer "line_number"
    t.string "external_id"
    t.string "raw_data", null: false
    t.string "description"
    t.decimal "amount", precision: 15, scale: 2
    t.date "event_date"
    t.date "payment_date"
    t.string "transaction_type"
    t.string "status"
    t.string "category_guess"
    t.string "installment_info"
    t.integer "installment_plan_id"
    t.integer "recurring_commitment_id"
    t.integer "matched_transaction_id"
    t.json "parsed_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "fingerprint", limit: 64
    t.integer "fingerprint_version", default: 1, null: false
    t.boolean "possible_duplicate", default: false, null: false
    t.boolean "transfer_candidate", default: false, null: false
    t.bigint "potential_transfer_with_id"
    t.index ["fingerprint"], name: "index_imported_transactions_on_fingerprint"
    t.index ["import_session_id"], name: "index_imported_transactions_on_import_session_id"
    t.index ["possible_duplicate"], name: "index_imported_transactions_on_possible_duplicate"
    t.index ["potential_transfer_with_id"], name: "index_imported_transactions_on_potential_transfer_with_id"
    t.index ["transfer_candidate"], name: "index_imported_transactions_on_transfer_candidate"
  end

  create_table "installment_plans", force: :cascade do |t|
    t.string "name", null: false
    t.integer "installment_count", null: false
    t.string "recurrence_frequency", default: "monthly", null: false
    t.date "starts_on", null: false
    t.integer "status", default: 0, null: false
    t.text "notes"
    t.decimal "total_amount", precision: 15, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "category_id", null: false
    t.integer "from_account_id"
    t.integer "to_account_id"
    t.index ["category_id"], name: "index_installment_plans_on_category_id"
    t.index ["from_account_id"], name: "index_installment_plans_on_from_account_id"
    t.index ["recurrence_frequency"], name: "index_installment_plans_on_recurrence_frequency"
    t.index ["status"], name: "index_installment_plans_on_status"
    t.index ["to_account_id"], name: "index_installment_plans_on_to_account_id"
    t.index ["user_id"], name: "index_installment_plans_on_user_id"
  end

  create_table "reconciliation_entries", force: :cascade do |t|
    t.integer "imported_transaction_id", null: false
    t.integer "transaction_id"
    t.string "action", null: false
    t.json "decision_data"
    t.integer "user_id", null: false
    t.datetime "decided_at", null: false
    t.text "audit_log"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["imported_transaction_id"], name: "index_reconciliation_entries_on_imported_transaction_id"
    t.index ["transaction_id"], name: "index_reconciliation_entries_on_transaction_id"
  end

  create_table "recurring_commitments", force: :cascade do |t|
    t.string "name", null: false
    t.integer "category_id", null: false
    t.decimal "default_amount", precision: 15, scale: 2
    t.string "recurrence_frequency", default: "monthly", null: false
    t.date "start_date", null: false
    t.date "end_date"
    t.integer "status", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "from_account_id", null: false
    t.integer "to_account_id", null: false
    t.index ["category_id"], name: "index_recurring_commitments_on_category_id"
    t.index ["from_account_id"], name: "index_recurring_commitments_on_from_account_id"
    t.index ["recurrence_frequency"], name: "index_recurring_commitments_on_recurrence_frequency"
    t.index ["status"], name: "index_recurring_commitments_on_status"
    t.index ["to_account_id"], name: "index_recurring_commitments_on_to_account_id"
    t.index ["user_id"], name: "index_recurring_commitments_on_user_id"
  end

  create_table "transaction_groups", force: :cascade do |t|
    t.string "name"
    t.string "group_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "starts_on"
    t.decimal "total_amount", precision: 15, scale: 2
    t.integer "installments_count"
  end

  create_table "transactions", force: :cascade do |t|
    t.string "description"
    t.decimal "amount"
    t.date "event_date"
    t.integer "category_id"
    t.integer "installment"
    t.integer "status", default: 0
    t.integer "recurrence_type", default: 0
    t.integer "transaction_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "payment_date"
    t.integer "credit_statement_id"
    t.integer "recurring_commitment_id"
    t.integer "installment_plan_id"
    t.string "recurrence_pattern"
    t.string "recurrence_frequency"
    t.integer "installment_number"
    t.integer "user_id", null: false
    t.integer "transaction_type", default: 1, null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["credit_statement_id"], name: "index_transactions_on_credit_statement_id"
    t.index ["installment_number"], name: "index_transactions_on_installment_number"
    t.index ["installment_plan_id"], name: "index_transactions_on_installment_plan_id"
    t.index ["recurrence_pattern"], name: "index_transactions_on_recurrence_pattern"
    t.index ["recurring_commitment_id"], name: "index_transactions_on_recurring_commitment_id"
    t.index ["transaction_group_id"], name: "index_transactions_on_transaction_group_id"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
    t.index ["user_id", "status", "event_date"], name: "index_transactions_on_user_status_event_date"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "accounts", "account_types"
  add_foreign_key "accounts", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "credit_statements", "accounts"
  add_foreign_key "entries", "accounts"
  add_foreign_key "entries", "transactions"
  add_foreign_key "import_sessions", "users"
  add_foreign_key "imported_transactions", "import_sessions"
  add_foreign_key "imported_transactions", "installment_plans"
  add_foreign_key "imported_transactions", "recurring_commitments"
  add_foreign_key "imported_transactions", "transactions", column: "matched_transaction_id"
  add_foreign_key "installment_plans", "accounts", column: "from_account_id"
  add_foreign_key "installment_plans", "accounts", column: "to_account_id"
  add_foreign_key "installment_plans", "categories"
  add_foreign_key "installment_plans", "users"
  add_foreign_key "reconciliation_entries", "imported_transactions"
  add_foreign_key "reconciliation_entries", "transactions"
  add_foreign_key "reconciliation_entries", "users"
  add_foreign_key "recurring_commitments", "accounts", column: "from_account_id"
  add_foreign_key "recurring_commitments", "accounts", column: "to_account_id"
  add_foreign_key "recurring_commitments", "categories"
  add_foreign_key "recurring_commitments", "users"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "credit_statements"
  add_foreign_key "transactions", "installment_plans"
  add_foreign_key "transactions", "recurring_commitments"
  add_foreign_key "transactions", "transaction_groups"
  add_foreign_key "transactions", "users"
end
