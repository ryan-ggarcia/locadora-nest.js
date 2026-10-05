import { Module } from '@nestjs/common';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { CategoryModule } from './category/category.module.js';

@Module({
  imports: [CategoryModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
