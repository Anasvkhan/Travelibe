import { prisma } from '../../prisma.js';

export class ShopService {
  static async updateProduct(productId, productData) {
    const { name, description, category, imageUrl, variants } = productData;
    return await prisma.$transaction(async (tx) => {
      const product = await tx.shopProduct.update({
        where: { id: productId },
        data: {
          name,
          description,
          category,
          imageUrl: imageUrl || null,
        },
      });

      if (variants && variants.length > 0) {
        const existingVariants = await tx.productVariant.findMany({
          where: { productId },
        });

        if (existingVariants.length > 0) {
          const mainVariant = existingVariants[0];
          const newVar = variants[0];
          await tx.productVariant.update({
            where: { id: mainVariant.id },
            data: {
              name: newVar.name,
              price: parseFloat(newVar.price),
              sku: newVar.sku,
              stockCount: parseInt(newVar.stockCount, 10),
            },
          });
        }
      }

      return product;
    });
  }

  static async deleteProduct(productId) {
    return await prisma.shopProduct.delete({
      where: { id: productId },
    });
  }

  // Product catalog management
  static async createProduct(productData) {
    const { name, description, category, imageUrl, variants } = productData;
    return await prisma.shopProduct.create({
      data: {
        name,
        description,
        category,
        imageUrl: imageUrl || null,
        variants: {
          create: variants || [],
        },
      },
      include: { variants: true },
    });
  }

  static async getProducts({ category } = {}) {
    const filter = {};
    if (category) filter.category = category;
    return await prisma.shopProduct.findMany({
      where: filter,
      include: { variants: true },
    });
  }

  // Cart Checkout
  static async checkoutOrder(userId, { items, shippingAddress }) {
    return await prisma.$transaction(async (tx) => {
      let totalAmount = 0.0;
      const orderItemsToCreate = [];

      for (const item of items) {
        const variant = await tx.productVariant.findUnique({
          where: { id: item.variantId },
        });

        if (!variant) throw new Error(`Product variant not found: ${item.variantId}`);
        if (variant.stockCount < item.quantity) {
          throw new Error(`Insufficient stock for product variant: ${variant.sku}`);
        }

        // Decrement stock count
        await tx.productVariant.update({
          where: { id: item.variantId },
          data: { stockCount: variant.stockCount - item.quantity },
        });

        const itemCost = variant.price * item.quantity;
        totalAmount += itemCost;

        orderItemsToCreate.push({
          variantId: item.variantId,
          quantity: item.quantity,
          price: variant.price,
        });
      }

      const taxAmount = totalAmount * 0.08; // 8% flat tax rate
      const shippingAmount = totalAmount > 50 ? 0.0 : 10.0; // free shipping over $50
      const orderTotal = totalAmount + taxAmount + shippingAmount;

      const order = await tx.shopOrder.create({
        data: {
          userId,
          totalAmount: orderTotal,
          taxAmount,
          shippingAmount,
          status: 'PAID',
          shippingAddress,
          items: {
            create: orderItemsToCreate,
          },
        },
        include: { items: true },
      });

      // Write payment transaction ledger
      await tx.ledgerEntry.create({
        data: {
          accountId: userId,
          entryType: 'DEBIT',
          amount: orderTotal,
          balanceAfter: 0.0,
          referenceType: 'PAYMENT',
          referenceId: order.id,
        },
      });

      await tx.ledgerEntry.create({
        data: {
          accountId: 'PLATFORM_SHOP',
          entryType: 'CREDIT',
          amount: orderTotal,
          balanceAfter: 0.0,
          referenceType: 'PAYMENT',
          referenceId: order.id,
        },
      });

      return order;
    });
  }

  // Boost Campaigns Management
  static async createBoostCampaign({ targetType, targetId, budgetCap, impressionPacing }) {
    // 1. Verify target post or plan exists
    if (targetType === 'POST') {
      const post = await prisma.post.findUnique({ where: { id: targetId } });
      if (!post) throw new Error('Target post for boost campaign not found');
      await prisma.post.update({ where: { id: targetId }, data: { isBoosted: true } });
    } else if (targetType === 'PLAN') {
      const plan = await prisma.tripPlan.findUnique({ where: { id: targetId } });
      if (!plan) throw new Error('Target trip plan for boost campaign not found');
    } else {
      throw new Error('Invalid boost campaign target type. Must be POST or PLAN.');
    }

    return await prisma.boostCampaign.create({
      data: {
        targetType,
        targetId,
        budgetCap: parseFloat(budgetCap),
        spendAccumulated: 0.0,
        impressionPacing: parseInt(impressionPacing || 10, 10),
        status: 'ACTIVE',
      },
    });
  }

  static async logBoostImpression(campaignId, costPerImpression = 0.01) {
    const campaign = await prisma.boostCampaign.findUnique({ where: { id: campaignId } });
    if (!campaign || campaign.status !== 'ACTIVE') return null;

    const newSpend = campaign.spendAccumulated + costPerImpression;
    const status = newSpend >= campaign.budgetCap ? 'COMPLETED' : 'ACTIVE';

    // If campaign is completed, reset boost tag in case of post
    if (status === 'COMPLETED' && campaign.targetType === 'POST') {
      await prisma.post.update({ where: { id: campaign.targetId }, data: { isBoosted: false } });
    }

    return await prisma.boostCampaign.update({
      where: { id: campaignId },
      data: {
        spendAccumulated: newSpend,
        status,
      },
    });
  }
}
export default ShopService;
