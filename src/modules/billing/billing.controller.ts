import { Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { BillingService } from './billing.service';

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
}
