import { prisma } from '../../prisma.js';

export class StaysService {
  static async createConsolidatedProperty(hostId, data) {
    const { name, location, address, description, imageUrl, commissionRate, roomName, roomType, maxOccupancy, basePricePerNight, inventoryCount } = data;
    
    return await prisma.$transaction(async (tx) => {
      const property = await tx.property.create({
        data: {
          hostId,
          name,
          location,
          address,
          description,
          imageUrl: imageUrl || null,
          commissionRate: commissionRate ? parseFloat(commissionRate) : 0.05,
        },
      });

      const unit = await tx.propertyUnit.create({
        data: {
          propertyId: property.id,
          name: roomName || 'Standard Room',
          roomType: roomType || 'Standard',
          maxOccupancy: parseInt(maxOccupancy, 10) || 2,
          basePricePerNight: parseFloat(basePricePerNight) || 100.0,
          inventoryCount: parseInt(inventoryCount, 10) || 5,
        },
      });

      return { ...property, units: [unit] };
    });
  }

  static async getAdminProperties() {
    return await prisma.property.findMany({
      include: {
        units: {
          include: {
            inventoryDays: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  static async updateProperty(propertyId, data) {
    const { name, location, address, description, imageUrl, commissionRate, roomName, roomType, maxOccupancy, basePricePerNight, inventoryCount } = data;
    
    return await prisma.$transaction(async (tx) => {
      const property = await tx.property.update({
        where: { id: propertyId },
        data: {
          name,
          location,
          address,
          description,
          imageUrl: imageUrl || null,
          commissionRate: commissionRate ? parseFloat(commissionRate) : 0.05,
        },
      });

      const firstUnit = await tx.propertyUnit.findFirst({
        where: { propertyId },
      });

      if (firstUnit) {
        await tx.propertyUnit.update({
          where: { id: firstUnit.id },
          data: {
            name: roomName,
            roomType,
            maxOccupancy: parseInt(maxOccupancy, 10),
            basePricePerNight: parseFloat(basePricePerNight),
            inventoryCount: parseInt(inventoryCount, 10),
          },
        });
      }

      return property;
    });
  }

  static async deleteProperty(propertyId) {
    return await prisma.property.delete({
      where: { id: propertyId },
    });
  }

  // Direct Host Listing Management
  static async createProperty(hostId, propertyData) {
    const { name, location, address, description, amenities, policies, taxesAndFees, commissionRate } = propertyData;
    return await prisma.property.create({
      data: {
        hostId,
        name,
        location,
        address,
        description,
        amenities,
        policies,
        taxesAndFees,
        commissionRate: commissionRate ? parseFloat(commissionRate) : 0.05,
      },
    });
  }

  static async createPropertyUnit(propertyId, unitData) {
    const { name, roomType, maxOccupancy, basePricePerNight, amenities, inventoryCount } = unitData;
    return await prisma.propertyUnit.create({
      data: {
        propertyId,
        name,
        roomType,
        maxOccupancy: parseInt(maxOccupancy, 10),
        basePricePerNight: parseFloat(basePricePerNight),
        amenities,
        inventoryCount: parseInt(inventoryCount, 10),
      },
    });
  }

  static async updateInventoryCalendar(unitId, { date, availableCount, price }) {
    return await prisma.inventoryDay.upsert({
      where: {
        propertyUnitId_date: {
          propertyUnitId: unitId,
          date,
        },
      },
      update: {
        availableCount: parseInt(availableCount, 10),
        price: parseFloat(price),
      },
      create: {
        propertyUnitId: unitId,
        date,
        availableCount: parseInt(availableCount, 10),
        price: parseFloat(price),
      },
    });
  }

  static async updateInventoryCalendarRange(unitId, { startDate, endDate, availableCount, price }) {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const results = [];
    
    while (start <= end) {
      const dateStr = start.toISOString().split('T')[0];
      
      const dayRecord = await prisma.inventoryDay.upsert({
        where: {
          propertyUnitId_date: {
            propertyUnitId: unitId,
            date: dateStr,
          },
        },
        update: {
          availableCount: parseInt(availableCount, 10),
          price: parseFloat(price),
        },
        create: {
          propertyUnitId: unitId,
          date: dateStr,
          availableCount: parseInt(availableCount, 10),
          price: parseFloat(price),
        },
      });
      
      results.push(dayRecord);
      start.setDate(start.getDate() + 1);
    }
    
    return results;
  }

  // Booking Search
  static async searchProperties({ destination, checkIn, checkOut, guests }) {
    // 1. Get properties in location
    const properties = await prisma.property.findMany({
      where: {
        location: { contains: destination, mode: 'insensitive' },
      },
      include: {
        units: {
          include: {
            inventoryDays: {
              where: {
                date: { gte: checkIn, lte: checkOut },
              },
            },
          },
        },
      },
    });

    // 2. Filter properties that have units with availability
    return properties.map((prop) => {
      const availableUnits = prop.units.filter((unit) => {
        // Enforce max occupancy check
        if (guests && unit.maxOccupancy < parseInt(guests, 10)) return false;

        // Check availability on dates
        const dateRange = this.getDateRangeArray(checkIn, checkOut);
        const daysWithInventory = unit.inventoryDays;

        // Verify every day in range has inventory >= 1
        return dateRange.every((dStr) => {
          const matchedDay = daysWithInventory.find((day) => day.date === dStr);
          // If no inventory day record exists, fallback to standard unit inventoryCount
          return matchedDay ? matchedDay.availableCount > 0 : unit.inventoryCount > 0;
        });
      });

      return {
        ...prop,
        units: availableUnits,
      };
    }).filter((prop) => prop.units.length > 0);
  }

  // Booking Transaction Flow
  static async createReservation(guestId, { unitId, checkIn, checkOut, idempotencyKey }) {
    // 1. Start database transaction block
    return await prisma.$transaction(async (tx) => {
      // Check existing reservation to prevent duplicate booking checks
      const existing = await tx.hotelReservation.findUnique({
        where: { idempotencyKey },
      });
      if (existing) return existing;

      // 2. Fetch the property unit and property config (for commission rate)
      const unit = await tx.propertyUnit.findUnique({
        where: { id: unitId },
        include: { property: true },
      });
      if (!unit) throw new Error('Selected lodging unit not found');

      // 3. Verify and update inventory count
      const dateRange = this.getDateRangeArray(checkIn, checkOut);
      let totalCost = 0.0;

      for (const dateStr of dateRange) {
        const inventoryDay = await tx.inventoryDay.findUnique({
          where: {
            propertyUnitId_date: {
              propertyUnitId: unitId,
              date: dateStr,
            },
          },
        });

        const currentCount = inventoryDay ? inventoryDay.availableCount : unit.inventoryCount;
        const currentPrice = inventoryDay ? inventoryDay.price : unit.basePricePerNight;

        if (currentCount <= 0) {
          throw new Error(`Lodging inventory unavailable on date: ${dateStr}`);
        }

        totalCost += currentPrice;

        // Decrement available count
        await tx.inventoryDay.upsert({
          where: {
            propertyUnitId_date: {
              propertyUnitId: unitId,
              date: dateStr,
            },
          },
          update: { availableCount: currentCount - 1 },
          create: {
            propertyUnitId: unitId,
            date: dateStr,
            availableCount: currentCount - 1,
            price: currentPrice,
          },
        });
      }

      // 4. Calculate commission (5% Travelibe retainer)
      const commission = totalCost * unit.property.commissionRate;

      // 5. Create reservation record
      const reservation = await tx.hotelReservation.create({
        data: {
          guestId,
          propertyId: unit.propertyId,
          propertyUnitId: unitId,
          checkIn,
          checkOut,
          bookingStatus: 'CONFIRMED',
          totalAmount: totalCost,
          commissionPaid: commission,
          idempotencyKey,
        },
      });

      // 6. Create ledger entries (Double-entry balance)
      // Debit Guest Account
      await tx.ledgerEntry.create({
        data: {
          accountId: guestId,
          entryType: 'DEBIT',
          amount: totalCost,
          balanceAfter: 0.0, // Calculated dynamically
          referenceType: 'PAYMENT',
          referenceId: reservation.id,
        },
      });

      // Credit Host Connected Account
      await tx.ledgerEntry.create({
        data: {
          accountId: unit.property.hostId,
          entryType: 'CREDIT',
          amount: totalCost - commission,
          balanceAfter: 0.0,
          referenceType: 'TRANSFER',
          referenceId: reservation.id,
        },
      });

      // Credit Travelibe Platform (5% Commission)
      await tx.ledgerEntry.create({
        data: {
          accountId: 'PLATFORM_RETAINER',
          entryType: 'CREDIT',
          amount: commission,
          balanceAfter: 0.0,
          referenceType: 'COMMISSION',
          referenceId: reservation.id,
        },
      });

      // 7. Write to transactional outbox
      await tx.outboxEvent.create({
        data: {
          eventType: 'booking.reservation.confirmed',
          payload: { reservationId: reservation.id, totalCost, commission },
        },
      });

      return reservation;
    });
  }

  // Utility to map array of dates between checkIn and checkOut (exclusive of checkOut day)
  static getDateRangeArray(checkIn, checkOut) {
    const start = new Date(checkIn);
    const end = new Date(checkOut);
    const dates = [];
    while (start < end) {
      dates.push(start.toISOString().split('T')[0]);
      start.setDate(start.getDate() + 1);
    }
    return dates;
  }
}
export default StaysService;
