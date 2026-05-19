import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { PropertyService } from './property.service';

@Controller('properties')
export class PropertyController {
  constructor(private readonly propertyService: PropertyService) {}

  @Get()
  findAll() {
    return this.propertyService.findAll();
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.propertyService.findOne(id);
  }

  @Get(':id/grid')
  getGridMatrix(@Param('id', ParseUUIDPipe) id: string) {
    return this.propertyService.getGridMatrix(id);
  }
}
