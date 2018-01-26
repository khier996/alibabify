class Product < ActiveRecord::Base
  has_many :variants, dependent: :destroy

  def self.copy_shopify(shopify_product)
    product = self.create(shopify_product_id: shopify_product.id,
                taobao_product_id: shopify_product.taobao_id,
                market: 'tmall',
                original_title: shopify_product.original_title,
                translated_title: shopify_product.title)
    copy_variants(product, shopify_product)
    return product
  end

  def self.random(sample_count)
    product_ids = Product.all.select(:id).map(&:id).sample(sample_count)
    Product.find(product_ids)
  end

  def incr_not_found
    self.not_found_count += 1
    if self.not_found_count >= 3 # coulnd't find corresponding shopify product 3 times. Means it was probably deleted.
      destroy
    else
      save
    end
  end

  def null_not_found
    self.update(not_found_count: 0)
  end

  private

  def self.copy_variants(product, shopify_product)
    shopify_product.variants.each do |shopify_variant|
      Variant.create(product_id: product.id,
                     shopify_variant_id: shopify_variant.id,
                     sku: shopify_variant.sku,
                     price: shopify_variant.price,
                     compare_at_price: shopify_variant.compare_at_price,
                     parsed: true)

    end
  end

end
