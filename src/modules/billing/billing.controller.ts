import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsIn,
  IsNumber,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { BillingService } from './billing.service';

class MeterReadingDto {
  @IsIn(['electricity', 'water'])
  utilityType!: 'electricity' | 'water';

  @IsNumber()
  @Min(0)
  previousReading!: number;

  @IsNumber()
  @Min(0)
  currentReading!: number;

  @IsNumber()
  @Min(0)
  ratePerUnit!: number;
}

class GenerateInvoiceBodyDto {
  @IsString()
  billingPeriod!: string;

  @IsDateString()
  dueDate!: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => MeterReadingDto)
  meterReadings!: MeterReadingDto[];
}

@Controller('billing')
export class BillingController {
  constructor(private readonly billingService: BillingService) {}

  @Get('invoices/:id')
  getInvoice(@Param('id', ParseUUIDPipe) id: string) {
    return this.billingService.getInvoice(id);
  }

  @Post('invoices/:id/issue')
  issueInvoice(@Param('id', ParseUUIDPipe) id: string) {
    return this.billingService.issueInvoice(id);
  }

  @Post('invoices/:id/promptpay-qr')
  createPromptPayQr(@Param('id', ParseUUIDPipe) id: string) {
    return this.billingService.createPromptPayQr(id);
  }

  @Post('leases/:leaseId/generate-invoice')
  generateInvoice(
    @Param('leaseId', ParseUUIDPipe) leaseId: string,
    @Body() body: GenerateInvoiceBodyDto,
  ) {
    return this.billingService.generateInvoice({ leaseId, ...body });
  }
}
