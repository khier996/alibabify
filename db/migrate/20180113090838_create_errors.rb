class CreateErrors < ActiveRecord::Migration
  def change
    create_table :errors do |t|
      t.string :url, null: false
      t.string :exception, null: false
      t.string :backtrace, null: false

      t.timestamps null: false
    end
  end
end
