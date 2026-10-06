export class CategoryEntity{
    private _cat_cod : number;
    private _cat_name : string;
    private _cat_daily : number;
    private _cat_dailyRate: number;
    private _cat_surplusValue: number;
    private _cat_minimumAge: number;
    private _cat_status: number;

    constructor(cod:number,name:string,daily:number,dailyRate:number,surplusValue:number,minimumAge:number,status:number){
        this._cat_cod = cod
        this._cat_name = name
        this._cat_daily = daily
        this._cat_dailyRate = dailyRate
        this._cat_surplusValue = surplusValue
        this._cat_minimumAge = minimumAge
        this._cat_status = status
    }

    get cat_cod():number { return this._cat_cod} 
    get cat_name():string { return this._cat_name}
    get cat_daily():number { return this._cat_daily}
    get cat_dailyRate():number { return this._cat_dailyRate}
    get cat_surplusValue():number { return this._cat_surplusValue}
    get cat_minimumAge():number { return this._cat_minimumAge}
    get cat_status():number { return this._cat_status}

    set cat_cod(value:number) { this._cat_cod = value}
    set cat_name(value:string) { this._cat_name = value}
    set cat_daily(value:number) { this._cat_daily = value}
    set cat_dailyRate(value:number) { this._cat_dailyRate = value}
    set cat_surplusValue(value:number) { this._cat_surplusValue = value}
    set cat_minimumAge(value:number) { this._cat_minimumAge = value}
    set cat_status(value:number) { this._cat_status = value}

    static Map(row:any){
        return new CategoryEntity(
            row['cat_cod'],
            row['cat_nome'],
            row['cat_valordiaria'],
            row['cat_kmlivrediaria'],
            row['cat_valorkmexcedente'],
            row['cat_idademinima'],
            row['cat_ativo'],
        )
    }

    Validation(){
        let errors = []
        if(this._cat_name == null || this._cat_name == undefined || this._cat_name == ""){
            errors.push("O nome da categoria é obrigatório\n")
        }
        if(this._cat_daily == null || this._cat_daily == undefined || this._cat_daily == 0){
            errors.push("O valor da diária da categoria é obrigatório\n")
        }
        if(this._cat_dailyRate == null || this._cat_dailyRate == undefined || this._cat_dailyRate == 0){
            errors.push("O valor do km livre da diária da categoria é obrigatório\n")
        }
        if(this._cat_surplusValue == null || this._cat_surplusValue == undefined || this._cat_surplusValue == 0){
            errors.push("O valor do km excedente da categoria é obrigatório\n")
        }
        if(this._cat_minimumAge == null || this._cat_minimumAge == undefined || this._cat_minimumAge == 0){
            errors.push("A idade mínima da categoria é obrigatória\n")
        }
        if(this._cat_status == null || this._cat_status == undefined || this._cat_status == 0){
            errors.push("O status da categoria é obrigatório\n")
        }

        if(errors.length > 0){
            throw new Error(errors.join(""))
        }else{
            return true
        }
    }
}