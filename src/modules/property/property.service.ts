import { Injectable, NotFoundException } from '@nestjs/common';

@Injectable()
export class PropertyService {
  async findAll(): Promise<unknown[]> {
    return [];
  }

  async findOne(id: string): Promise<unknown> {
    const property = await this.findPropertyById(id);
    if (!property) {
      throw new NotFoundException(`Property ${id} not found`);
    }
    return property;
  }

  async getGridMatrix(propertyId: string): Promise<{
    propertyId: string;
    gridRows: number;
    gridColumns: number;
    rooms: unknown[];
  }> {
    const property = await this.findPropertyById(propertyId);
    if (!property) {
      throw new NotFoundException(`Property ${propertyId} not found`);
    }
    return {
      propertyId,
      gridRows: 0,
      gridColumns: 0,
      rooms: [],
    };
  }

  private async findPropertyById(_id: string): Promise<unknown | null> {
    return null;
  }
}
