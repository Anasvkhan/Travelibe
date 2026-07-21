import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const plans = await prisma.tripPlan.findMany();
  console.log("All Plans in DB:");
  console.dir(plans, { depth: null });
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
