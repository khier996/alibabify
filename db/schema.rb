# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171224041159) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "products", force: :cascade do |t|
    t.string   "taobao_product_id",  null: false
    t.string   "shopify_product_id", null: false
    t.string   "market",             null: false
    t.string   "original_title",     null: false
    t.string   "translated_title",   null: false
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  add_index "products", ["shopify_product_id"], name: "index_products_on_shopify_product_id", using: :btree
  add_index "products", ["taobao_product_id"], name: "index_products_on_taobao_product_id", using: :btree

  create_table "shops", force: :cascade do |t|
    t.string   "shopify_domain", null: false
    t.string   "shopify_token",  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "shops", ["shopify_domain"], name: "index_shops_on_shopify_domain", unique: true, using: :btree

  create_table "variants", force: :cascade do |t|
    t.integer  "product_id",                         null: false
    t.string   "shopify_variant_id"
    t.string   "sku"
    t.boolean  "parsed",             default: false
    t.decimal  "price"
    t.decimal  "compare_at_price"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "variants", ["product_id"], name: "index_variants_on_product_id", using: :btree
  add_index "variants", ["shopify_variant_id"], name: "index_variants_on_shopify_variant_id", using: :btree

end
