import { Module } from '@nestjs/common';
import { CategoryController } from './category/category.controller.js';

@Module({
  imports: [],
  controllers: [CategoryController],
  providers: [],
})
export class AppModule {}
