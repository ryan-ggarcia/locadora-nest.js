import { Body, Controller, Get, Post } from '@nestjs/common';
import { CreateCategoryDto } from './category.dto.js';

@Controller('category')
export class CategoryController {
    @Get()
    read() :string{
        return "Olá mundo"
    }

    @Post()
    async create(@Body() createDto : CreateCategoryDto){
        return 'Olá'
    }
}
