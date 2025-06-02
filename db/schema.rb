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

ActiveRecord::Schema[7.1].define(version: 2025_06_02_141128) do
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
    t.index ["account_type_id"], name: "index_accounts_on_account_type_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["recurrence_frequency"], name: "index_installment_plans_on_recurrence_frequency"
    t.index ["status"], name: "index_installment_plans_on_status"
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
    t.index ["category_id"], name: "index_recurring_commitments_on_category_id"
    t.index ["recurrence_frequency"], name: "index_recurring_commitments_on_recurrence_frequency"
    t.index ["status"], name: "index_recurring_commitments_on_status"
  end

  create_table "transaction_groups", force: :cascade do |t|
    t.string "name"
    t.string "group_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "installment_count", default: 1
    t.date "starts_on"
    t.decimal "total_amount", precision: 15, scale: 2
    t.integer "installments_count"
  end

  create_table "transactions", force: :cascade do |t|
    t.string "description"
    t.decimal "amount"
    t.string "transaction_type"
    t.date "event_date"
    t.integer "from_account_id", null: false
    t.integer "to_account_id"
    t.integer "category_id", null: false
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
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["credit_statement_id"], name: "index_transactions_on_credit_statement_id"
    t.index ["from_account_id"], name: "index_transactions_on_from_account_id"
    t.index ["installment_number"], name: "index_transactions_on_installment_number"
    t.index ["installment_plan_id"], name: "index_transactions_on_installment_plan_id"
    t.index ["recurrence_pattern"], name: "index_transactions_on_recurrence_pattern"
    t.index ["recurring_commitment_id"], name: "index_transactions_on_recurring_commitment_id"
    t.index ["to_account_id"], name: "index_transactions_on_to_account_id"
    t.index ["transaction_group_id"], name: "index_transactions_on_transaction_group_id"
  end

  add_foreign_key "accounts", "account_types"
  add_foreign_key "credit_statements", "accounts"
  add_foreign_key "recurring_commitments", "categories"
  add_foreign_key "transactions", "accounts", column: "from_account_id"
  add_foreign_key "transactions", "accounts", column: "to_account_id"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "credit_statements"
  add_foreign_key "transactions", "installment_plans"
  add_foreign_key "transactions", "recurring_commitments"
  add_foreign_key "transactions", "transaction_groups"
end
