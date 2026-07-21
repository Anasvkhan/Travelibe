import pkg from '@prisma/client';
const { PrismaClient } = pkg;
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding initial data for Travelibe...');

  // Clean up existing seeded products and properties to prevent duplicate key/SKU errors
  await prisma.shopProduct.deleteMany({});
  await prisma.property.deleteMany({});

  const passwordHash = await bcrypt.hash('password123', 10);

  // 1. Create initial Admin
  const admin = await prisma.user.upsert({
    where: { email: 'admin@travelibe.com' },
    update: {},
    create: {
      email: 'admin@travelibe.com',
      passwordHash,
      role: 'SUPERADMIN',
      profile: {
        create: {
          handle: 'admin',
          displayName: 'System Admin',
          verificationTier: 'HOST_KYC',
        },
      },
    },
  });

  // 2. Create a Host User
  const host = await prisma.user.upsert({
    where: { email: 'host@travelibe.com' },
    update: {},
    create: {
      email: 'host@travelibe.com',
      passwordHash,
      role: 'USER',
      profile: {
        create: {
          handle: 'travel_host',
          displayName: 'Premium Accommodations Host',
          verificationTier: 'HOST_KYC',
        },
      },
    },
  });

  // 3. Create a Property with Units
  const property = await prisma.property.create({
    data: {
      hostId: host.id,
      name: 'Seaside Sanctuary Resort',
      location: 'Bali, Indonesia',
      address: 'Jalan Pantai No. 42, Kuta, Bali',
      description: 'A serene beachside resort perfect for digital nomads and group travels.',
      amenities: ['wifi', 'pool', 'beachfront', 'gym', 'co-working space'],
      commissionRate: 0.05,
      isVerified: true,
      units: {
        create: [
          {
            name: 'Ocean View Deluxe Room',
            roomType: 'Deluxe Suite',
            maxOccupancy: 2,
            basePricePerNight: 120.00,
            amenities: ['AC', 'mini-fridge', 'ocean-balcony'],
            inventoryCount: 5,
          },
          {
            name: 'Nomad Shared Loft',
            roomType: 'Dormitory',
            maxOccupancy: 1,
            basePricePerNight: 35.00,
            amenities: ['AC', 'personal-locker', 'dedicated-desk'],
            inventoryCount: 12,
          },
        ],
      },
    },
  });

  // 4. Create Branded Commerce Products
  await prisma.shopProduct.create({
    data: {
      name: 'Travelibe Explorer Pack',
      description: 'Ultra-lightweight water-resistant backpack with smart compartments.',
      category: 'backpacks',
      isPublished: true,
      variants: {
        create: [
          { name: 'Teal Medium', price: 89.99, sku: 'TB-EXPACK-TL-M', stockCount: 150 },
          { name: 'Coral Large', price: 99.99, sku: 'TB-EXPACK-CR-L', stockCount: 80 },
        ],
      },
    },
  });

  await prisma.shopProduct.create({
    data: {
      name: 'Smart Travel Compression Cubes',
      description: 'Set of 4 compression packing cubes for space-saving organization.',
      category: 'organizers',
      isPublished: true,
      variants: {
        create: [
          { name: 'Teal Pack', price: 34.99, sku: 'TB-CUBES-TL-4', stockCount: 300 },
        ],
      },
    },
  });

  console.log('Database seeding completed successfully.');
}

main()
  .catch((e) => {
    console.error('Error during seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
