"""What traders, consoles and paid services offer, read from source. No BYOND or running world needed.

Numbers here are read from the code. Expressions and random ranges stay explicit rather than estimated. The small
adapters below follow constructors, shelf stamping and cargo generators that were read by hand from their procs.
Rows keep the flat text shape they have always had: lists and dicts as JSON text, numbers as text.
"""
from __future__ import annotations

import collections
import json
import math
import re

from .dm_reader import inherited_proc, paths_in, proc_chain

PEDDLER_SHOP = '/datum/outpost_shop/vendor/peddler'
PEDDLER_WEAPONS = '/datum/shop_sku/peddler/weapon'
PEDDLER_ZONES = ['green', 'yellow', 'red']

def scalar(v):
    if v is None: return ''
    if isinstance(v,(list,dict,tuple)): return json.dumps(v,ensure_ascii=False,separators=(',',':'))
    return v

CAT_FIELDS = ['evidence','shop','shop_type','seller_npc','outpost','zone','shelf','sku_type','item_path','item_name','sku_name','price_credits','price_vouchers','other_currency','stock','stock_min','stock_max','restock_rule','fixed_price','contract_reward','zone_permission','dispense_amount','delivered_units','crew_limit','rotation_type','rotation_weight','rotation_slots','source','field_sources','notes']
BUY_FIELDS = ['evidence','shop','shop_type','seller_npc','outpost','zone','kind','entry_type','item_path','item_name','amount','pay_credits','pay_vouchers','other_payment','demand','demand_max','refill_rule','match_subtypes','source','field_sources','match_rule','notes']
CARGO_FIELDS = ['evidence','pack_type','name','group','cost','cost_rule','availability','contents_summary','contains','source','field_sources','notes']

def contexts(dm):
    overmap='voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm'
    txt=dm.texts[overmap]
    main={}
    for m in re.finditer(r'list\("shop"\s*=\s*(/datum/outpost_shop/\w+),\s*"zone"\s*=\s*ZONE_(\w+)',txt): main[m[1]]=m[2].lower()
    # Inspect the actual placement list rather than infer zone from price or SKU.
    if not main:
        for zone,shop in re.findall(r'ZONE_(GREEN|YELLOW|RED)\s*=\s*(/datum/outpost_shop/\w+)',txt): main[shop]=zone.lower()
    known={'general':'green','outfitter':'yellow','black_market':'red'}
    if not main:
        # setup_trader_outposts uses a list(shop_type, zone), parsed here.
        for shop,zone in re.findall(r'(/datum/outpost_shop/(?:general|outfitter|black_market))[^\n]*ZONE_(GREEN|YELLOW|RED)',txt): main[shop]=zone.lower()
    if not main:
        for zone,key in re.findall(r'"\[ZONE_(GREEN|YELLOW|RED)\]"\s*=\s*/obj/structure/overmap/trader_outpost/(\w+)',txt): main['/datum/outpost_shop/'+key]=zone.lower()
    assert main == {f'/datum/outpost_shop/{k}':v for k,v in known.items()}, main
    result={}
    # Shop type references on mapped trader NPCs establish the host outpost.
    map_root=dm.root/'voidcrew/_maps/map_files/outposts'
    for key,zone in known.items():
        host=dm.val('/datum/outpost_shop/'+key,'outpost_name')
        map_text=(map_root/f'trader_outpost_{key}.dmm').read_text(encoding='utf-8')
        result['/datum/outpost_shop/'+key]=(host,zone)
        for npc in re.findall(r'/mob/living/basic/outpost_trader(?:/\w+)*',map_text):
            shop=dm.val(npc,'shop_type')
            if shop: result[shop]=(host,zone)
    result['/datum/outpost_shop/vendor/peddler']=('Planet caravan (generated name)','green|yellow|red')
    result['/datum/outpost_shop/vendor/colosseum_armory']=('Grand Colosseum','yellow')
    return result

def item_name(dm,path):
    return dm.val(path,'name') if path else ''

def f_sources(dm,path,fields): return {f:dm.field(path,f).source for f in fields}

def catalog(dm,ctx):
    rows=[]; buys=[]; used=set()
    for shop,(host,zone) in sorted(ctx.items()):
        common=dict(evidence='CODE',shop=dm.val(shop,'outpost_name'),shop_type=shop,seller_npc=dm.val(shop,'trader_name'),outpost=host,zone=zone)
        shelves=[]
        for key,label in [('sku_types','core'),('rotating_pool','rotating pool'),('rare_pool','rare pool'),('favor_sku_types','back room'),('chart_pool','rotating pool')]:
            for sku in dm.val(shop,key) or []: shelves.append((sku,label,key,None,None))
        for rotation in dm.val(shop,'rotations') or []:
            for entry in dm.val(rotation,'pool') or []:
                sku,weight=entry if isinstance(entry,tuple) else (entry,1)
                shelves.append((sku,'weighted rotation','rotations',rotation,weight))
        pack_weapon_zone={}
        if shop==PEDDLER_SHOP:
            # ambient_peddler_weapons() picks one from the planet's zone, so these are on no shelf list.
            for band in PEDDLER_ZONES:
                for sku in dm.paths(f'{PEDDLER_WEAPONS}/{band}'):
                    if dm.val(sku,'item_path'):
                        shelves.append((sku,'pack weapon','sku_types',None,None)); pack_weapon_zone[sku]=band
        for sku,shelf,key,rotation,weight in shelves:
            assert sku in dm.headers, ('Missing SKU',sku)
            used.add(sku); notes=[]
            values={f:dm.val(sku,f) for f in ['item_path','price_credits','price_vouchers','stock_min','stock_max','fixed_price','contract_reward','zone_permission','dispense_amount','crew_limit']}
            lo,hi=values['stock_min'],values['stock_max']
            if shelf in ('rotating pool','weighted rotation'): lo,hi=max(1,min(2,lo)),max(1,min(2,hi))
            if shelf=='rare pool': lo=hi=1
            if shelf=='back room': lo=hi=dm.eval('FAVOR_UNIQUE_CREW_LIMIT')
            stock=str(lo) if lo==hi else f'rand({lo},{hi})'
            if shelf=='back room': stock=f'{lo} per crew; shared stock not decremented'
            interval=dm.val(sku,'restock_interval')
            event='convoy every 22 minutes'
            if 'colosseum' in shop: event='after each settled match'
            if 'peddler' in shop: event='none; visit ledger persists, caravan leaves for round'
            if interval and interval >= 1e30: restock='never (INFINITY)'
            elif interval: restock=f'+1 every {interval/10:g} seconds up to stock_max minus reservations; independent timer'
            elif shelf=='back room': restock='no refill; crew purchase cap for round'
            elif 'peddler' in shop: restock=event
            elif dm.is_a(sku,'/datum/shop_sku/ruin_chart'): restock=f'{event}: refill to stock_max; fresh encounter per purchase'
            elif shelf=='core' and (dm.val(sku,'convoys_per_unit') or 1)>1: restock=f"+1 every {dm.val(sku,'convoys_per_unit')} convoys, capped at stock_max minus reservations"
            elif shelf=='core': restock=f'{event}: +max(1,round(stock_max/2)), capped at stock_max minus reservations'
            elif shelf=='weighted rotation': restock=f'{event}: every sold-out slot swaps to a different weighted pool type'
            elif dm.val(sku,'is_chart'): restock=f'{event}: no refill or replacement for this non-ruin chart'
            elif shelf=='rotating pool': restock=f'{event}: one sold-out ordinary rotating slot swaps to an absent pool type (fallback any pool type)'
            else: restock='no refill (rare showcase)'
            path=values['item_path']; name=item_name(dm,path)
            display=dm.val(sku,'name') or name
            if dm.is_a(sku,'/datum/shop_sku/anomaly_chart'):
                display='anomaly chart: '+str(item_name(dm,dm.val(sku,'anomaly_type')))
                notes.append('Computed name in anomaly_chart/New; no physical item, uploads sealed chart to hull')
            if not path: notes.append('Service/intel; no physical item_path')
            other=''
            if dm.is_a(sku,'/datum/shop_sku/barter'):
                other={'item_path':dm.val(sku,'barter_path'),'amount':dm.val(sku,'barter_amount')}
                notes.append('Barter: consumes a held matching item/stack; see try_purchase override')
            if dm.val(sku,'is_chart'): notes.append('Chart pool destination band is independent of seller zone')
            for proc_key in [sku+'/New',sku+'/dispense']:
                if proc_key in dm.procs: notes.append('Runtime override: '+'; '.join(s for s,t in dm.procs[proc_key]))
            fields=f_sources(dm,sku,values)
            fields.update(item_name=dm.field(path,'name').source if path else '',shelf=dm.field(shop,key).source)
            row=dict(common,shelf=shelf,sku_type=sku,item_name=name,sku_name=display,other_currency=other,stock=stock,restock_rule=restock,rotation_type=rotation,rotation_weight=weight,rotation_slots=dm.val(rotation,'slots') if rotation else '',source=dm.loc(sku),field_sources=fields,notes='; '.join(notes),**values)
            if sku in pack_weapon_zone: row['zone']=pack_weapon_zone[sku]
            rows.append(row)
        for entry in dm.val(shop,'buyback_types') or []:
            values={f:dm.val(entry,f) for f in ['item_path','amount','pay_credits','pay_vouchers','demand_max','match_subtypes']}
            demand=f'rand({dm.val(entry,"demand_min")},{values["demand_max"]})'
            notes=[]
            if 'peddler' in shop:
                values['pay_credits']=math.floor(values['pay_credits']*.7/5)*5; values['pay_vouchers']=0; demand='rand(1,3)'
                notes.append('Computed in peddler/New: round(original credits*0.7,5), zero vouchers; demand saved across unload/reload')
            gas=dm.val(entry,'gas_type')
            if gas: notes.append(f'Consumes whole tank containing >= {dm.val(entry,"required_moles")} mol of {gas}')
            refill='convoy every 22 minutes: +max(1,round(demand_max/2)), capped at demand_max'
            if 'peddler' in shop: refill='none; site saves remaining demand; no convoy'
            buys.append(dict(common,kind='buyback',entry_type=entry,item_name=dm.val(entry,'name') or item_name(dm,values['item_path']),other_payment='',demand=demand,refill_rule=refill,source=dm.loc(entry),field_sources=f_sources(dm,entry,list(values)+['demand_min','gas_type','required_moles']),notes='; '.join(notes),**values))
    return rows,buys,used

def ladder_restricted(dm,path):
    # Faithful typecache tests from weapon_ladder.dm, not a price/name heuristic.
    if dm.is_a(path,'/obj/item/gun'):
        tools=paths_in(dm.proc('/proc/is_ladder_combat_gun').split('typecacheof(list(',1)[1].split('))',1)[0])
        if path != '/obj/item/gun/syringe' and not any(dm.is_a(path,p) for p in tools): return True
    melee=dm.proc('/proc/is_ladder_restricted_melee')
    exempt=paths_in(melee.split('return FALSE',1)[0])
    if not any(dm.is_a(path,p) for p in exempt):
        restricted=paths_in(melee.split('typecacheof(list(',1)[1].split('))',1)[0])
        if any(dm.is_a(path,p) for p in restricted): return True
    roots=paths_in(dm.proc('/proc/is_ladder_restricted_production'))
    return any(dm.is_a(path,p) for p in roots)

def cargo(dm):
    rows=[]; rejected=collections.defaultdict(list)
    forbidden=paths_in(dm.proc('/obj/machinery/computer/voidcrew_cargo/can_order_pack').split('typecacheof(list(',1)[1].split('))',1)[0])
    removed=paths_in(dm.texts['voidcrew/modules/cargo/anomaly_packs.dm'].split('GLOBAL_LIST_INIT',1)[1].split(')))',1)[0])
    for pack in dm.paths('/datum/supply_pack'):
        if pack=='/datum/supply_pack': continue
        contains=dm.val(pack,'contains')
        if contains is None: rejected['unregistered (null contains / abstract / runtime only)'].append(pack); continue
        if any(dm.is_a(pack,p) for p in removed): rejected['raw anomaly pack removed in New'].append(pack); continue
        if any(dm.is_a(pack,p) for p in forbidden): rejected['forbidden pack typecache'].append(pack); continue
        item_paths=[x[0] if isinstance(x,tuple) else x for x in contains]
        if any(isinstance(p,str) and ladder_restricted(dm,p) for p in item_paths): rejected['restricted production in contains'].append(pack); continue
        if dm.val(pack,'drop_pod_only'): rejected['drop_pod_only'].append(pack); continue
        if pack=='/datum/supply_pack/materials/gas_canisters': continue # generator replaces this record
        notes=[]; conditions=[]
        if dm.val(pack,'hidden'): conditions.append('emagged console')
        if dm.val(pack,'contraband'): conditions.append('contraband enabled')
        if dm.val(pack,'special'):
            conditions.append('special_enabled (runtime unlock)' if not dm.val(pack,'special_enabled') else 'special_enabled by default')
        fills=inherited_proc(dm,pack,'fill')
        if fills and fills[0][0] != dm.procs['/datum/supply_pack/fill'][0][0]:
            notes.append('Custom fill: '+'; '.join(s for s,t in fills))
        contents=[]
        for entry in contains:
            path,count=entry if isinstance(entry,tuple) else (entry,1)
            contents.append(f'{count}x {item_name(dm,path) or path}')
        summary='; '.join(contents[:6])
        if len(contents)>6: summary+=f'; +{len(contents)-6} other declared types (see contains)'
        if notes: summary = 'Custom fill: '+str(dm.val(pack,'desc') or dm.val(pack,'name'))[:180]+'; declared contents/pool in contains'
        rows.append(dict(evidence='CODE',pack_type=pack,name=dm.val(pack,'name'),group=dm.val(pack,'group'),cost=dm.val(pack,'cost'),cost_rule='cost * SSeconomy.pack_price_modifier (initial 1); coupons when eligible',availability='; '.join(conditions) or 'ordinary console',contents_summary=summary,contains=contains,source=dm.loc(pack),field_sources=f_sources(dm,pack,['name','cost','contains','hidden','contraband','special','special_enabled','drop_pod_only']),notes='; '.join(notes)))
    generator='/datum/supply_pack/materials/gas_canisters'
    canister='/obj/machinery/portable_atmospherics/canister'
    moles=dm.val(canister,'maximum_pressure')*dm.val(canister,'filled')*dm.val(canister,'volume')/(dm.eval('R_IDEAL_GAS_EQUATION')*dm.eval('T20C'))
    for gas in dm.paths('/datum/gas'):
        if not dm.val(gas,'purchaseable'): continue
        mapping=dm.proc('/proc/init_gas_id_to_canister')
        path=None
        for gas_id,can in re.findall(r'(GAS_\w+)\s*=\s*(/obj/[\w/]+)',mapping):
            if dm.eval(gas_id)==dm.val(gas,'id'): path=can; break
        assert path,gas
        cost=math.ceil((dm.val(generator,'cost')+moles*dm.val(gas,'base_value')*1.6)/10)*10
        rows.append(dict(evidence='CODE',pack_type=generator+'('+dm.val(gas,'name')+')',name=dm.val(gas,'name')+' Canister',group=dm.val(generator,'group'),cost=cost,cost_rule='CEILING(generator.cost + default_canister_moles * gas.base_value * 1.6, 10) * pack_price_modifier',availability='ordinary console',contents_summary='1x '+str(item_name(dm,path)),contains=[path],source=dm.procs[generator+'/generate_supply_packs'][0][0],field_sources=dict(gas=dm.loc(gas),**f_sources(dm,gas,['base_value','purchaseable']),generator_cost=dm.field(generator,'cost').source),notes=f'Computed generated pack; default canister moles={moles:.9g}; replaced generator template'))
    rows.append(dict(evidence='CODE',pack_type='/datum/supply_pack/custom/minerals (runtime order)',name='Materials Order',group='Materials market',cost='live material ask * ordered quantity',cost_rule='runtime cost passed to custom/minerals/New; validated and committed by materials order path',availability='hidden mineral-order exception; valid_material_order_contents',contents_summary='Player-selected permitted material sheets and quantities',contains='runtime validated material contents',source=dm.procs['/datum/supply_pack/custom/minerals/New'][0][0],field_sources={'filter':dm.procs['/obj/machinery/computer/voidcrew_cargo/can_order_pack'][0][0]},notes='Runtime pack, not a fixed registry entry; also represented in catalog.csv as a dynamic market channel'))
    return rows,rejected

def extra_catalog(dm,rows):
    def add(shop,name,source,price=0,vouchers=0,**kw):
        row=dict(evidence='CODE',shop=shop,shop_type=kw.pop('shop_type','service'),seller_npc=kw.pop('seller_npc','Service terminal'),outpost=kw.pop('outpost','Player outpost / portable machine'),zone=kw.pop('zone','green|yellow|red'),shelf=kw.pop('shelf','other'),sku_type=kw.pop('sku_type',source.split(':')[0]+'#'+name),item_path='',item_name=name,sku_name=name,price_credits=price,price_vouchers=vouchers,other_currency='',stock='unlimited service',stock_min='',stock_max='',restock_rule='not stock limited; per-use validation',fixed_price=1,contract_reward=0,zone_permission=0,dispense_amount=1,crew_limit=0,rotation_type='',rotation_weight='',rotation_slots='',source=source,field_sources={},notes='')
        row.update(kw); rows.append(row)
    for upgrade in dm.paths('/datum/mod_upgrade'):
        if not dm.val(upgrade,'id'): continue
        add('MOD fitting bench',dm.val(upgrade,'name'),dm.loc(upgrade),dm.val(upgrade,'price_credits'),dm.val(upgrade,'price_vouchers'),sku_type=upgrade,zone_permission=dm.val(upgrade,'zone_permission'),outpost='Quartermain Depot; constructible bench',seller_npc='Wick / MOD fitting bench',notes='Requires '+str(dm.val(upgrade,'requires') or 'none')+'; '+str(dm.val(upgrade,'desc')),field_sources=f_sources(dm,upgrade,['price_credits','price_vouchers','requires','id']))
    file='voidcrew/modules/cyberware/chrome_cradle.dm'
    add('Chrome cradle','chrome tune-up',dm.cite(file,'if(!charge_fee(patient, CYBERWARE_TUNEUP_FEE'),dm.eval('CYBERWARE_TUNEUP_FEE'),outpost='Undertow Exchange; constructible chrome cradle',seller_npc='Splice / Chrome Cradle',notes='Repair installed chrome and clear EMP scramble; charged each use')
    file='voidcrew/modules/trade/outpost_amenities.dm'
    add('Rental stash locker','round locker rental',dm.cite(file,'#define OUTPOST_LOCKER_RENTAL_FEE'),dm.eval('OUTPOST_LOCKER_RENTAL_FEE'),outpost='Quartermain Depot',zone='yellow',stock='one rental per physical locker per round',notes='ID-bound rental; not a SKU')
    file='voidcrew/modules/player_outposts/outpost_market.dm'
    table=dm.texts[file].split('GLOBAL_LIST_INIT(outpost_price_table, list(',1)[1].split('))',1)[0]
    for m in re.finditer(r'(OUTPOST_PRICE_\w+)\s*=\s*list\("label"\s*=\s*"([^"]+)",\s*"default"\s*=\s*(\w+),\s*"max"\s*=\s*(\w+)',table):
        add('Player outpost services',m[2],dm.cite(file,m[0]),f'owner-set 0..{dm.eval(m[4])}; default {dm.eval(m[3])}',notes='Members use services free; visitor ID pays treasury; ownerless outpost free; installed service required',sku_type=m[1])
    add('Player outpost owner shop','runtime player-stocked listing',dm.loc('/datum/outpost_shop_listing'),'owner-set per item or stack unit',sku_type='/datum/outpost_shop_listing',item_path='runtime /obj/item subtype',stock='physical deposited units',restock_rule='staff deposits physical stock',notes='Runtime names, goods and prices cannot be enumerated from branch source; managers/pricers take stock free; price 0 is not for sale')
    for upgrade in dm.paths('/datum/outpost_upgrade'):
        if not dm.val(upgrade,'id') or not dm.val(upgrade,'price'): continue
        add('Player outpost upgrades',dm.val(upgrade,'name'),dm.loc(upgrade),dm.val(upgrade,'price'),sku_type=upgrade,stock='installation gated',notes='Treasury buys upgrade blueprint; not a ship purchase',field_sources=f_sources(dm,upgrade,['price','id']))
    # Other paid registry services; ship purchase prices deliberately excluded.
    for file,needle,name,const in [
        ('voidcrew/modules/player_outposts/outpost_checkpoints.dm','OUTPOST_CHECKPOINT_SAVE_COST','save ship checkpoint','OUTPOST_CHECKPOINT_SAVE_COST'),
        ('voidcrew/modules/player_outposts/outpost_checkpoints.dm','OUTPOST_CHECKPOINT_UPDATE_COST','update ship checkpoint','OUTPOST_CHECKPOINT_UPDATE_COST'),
        ('voidcrew/modules/player_outposts/outpost_management_ui.dm','OUTPOST_ADVERT_COST','galaxy advertisement','OUTPOST_ADVERT_COST'),
        ('voidcrew/modules/player_outposts/outpost_ship_bay.dm','OUTPOST_SHIP_BAY_COST','install ship bay','OUTPOST_SHIP_BAY_COST')]:
        add('Player outpost registry',name,dm.cite(file,needle),dm.eval(const),notes='Paid from treasury; runtime eligibility applies')
    for console in dm.paths('/obj/machinery/computer/order_console'):
        categories=dm.val(console,'order_categories')
        if not categories: continue
        currency=dm.val(console,'credit_type') or 'credits'
        for offer in dm.paths('/datum/orderable_item'):
            path=dm.val(offer,'purchase_path')
            if not path or dm.val(offer,'category_index') not in categories: continue
            price=dm.val(offer,'cost_per_order')
            express=dm.val(console,'express_cost_multiplier')
            cargo_mult=dm.val(console,'cargo_cost_multiplier')
            forced=dm.val(console,'forced_express') or dm.is_a(console,'/obj/machinery/computer/order_console/mining')
            amounts={'currency':currency,'express_per_item':price*express,'cargo_per_item':None if forced else price*cargo_mult,'rounding':'round(total cart * chosen multiplier)'}
            is_credit=currency in ('credit','credits')
            if is_credit: credits=f'{math.floor(price*express)} one-item express; '+('express only' if forced else f'{math.floor(price*cargo_mult)} one-item cargo')
            else: credits=0
            add(str(dm.val(console,'name')),dm.val(offer,'name') or item_name(dm,path),dm.loc(offer),credits,shop_type=console,sku_type=offer,shelf='vendor machine',item_path=path,item_name=item_name(dm,path),outpost='Mapped ship/ruin console or constructible console',other_currency=amounts if not is_credit else '',stock='unlimited (account payment required)',notes='No weapon-ladder filter on this order-console path; full-cart charge rule='+scalar(amounts)+'; '+('Mining Initialize forces express; branch cargo multiplier is 1.' if 'mining' in console else ''),field_sources=f_sources(dm,offer,['purchase_path','cost_per_order','category_index']))
    for offer in dm.paths('/datum/voucher_set/mining'):
        items=dm.val(offer,'set_items')
        if not items: continue
        add('Mining voucher redeemer',dm.val(offer,'name'),dm.loc(offer),sku_type=offer,shelf='vendor machine',outpost='Mining and golem equipment consoles',other_currency={'item_path':'/obj/item/mining_voucher','amount':1},item_path=items,item_name=dm.val(offer,'name'),stock='one set per voucher',notes='set_items='+scalar(items)+'; redemption at mining console; distinct from trade vouchers')
    prison='/obj/machinery/vending/sustenance/outpost_prison'
    for entry in dm.val(prison,'products') or []:
        path,count=entry if isinstance(entry,tuple) else (entry,1)
        add('Prison sustenance vendor',item_name(dm,path),dm.loc(prison),dm.eval('OUTPOST_PRISON_RATION_COST'),shop_type=prison,sku_type=prison+'#'+path,shelf='vendor machine',item_path=path,stock=count,stock_max=count,outpost='Player outpost prison wing',restock_rule='one unit per powered minute, weighted by shortage',notes='Explicit vend override charges treasury even though ordinary vending is free. Returned products free; shared resident limit 8 purchases/10 minutes; managers/treasurers exempt from resident limit',field_sources=f_sources(dm,prison,['products','default_price']))
    add('Prison guard hiring','hire prison guard',dm.cite('voidcrew/modules/player_outposts/outpost_prison_guards.dm','/datum/outpost_prison/proc/hire_guard'),dm.eval('OUTPOST_GUARD_HIRE_COST'),outpost='Player outpost prison wing',stock='up to '+str(dm.eval('OUTPOST_GUARD_MAX'))+' guards',notes='Treasury also pays '+str(dm.eval('OUTPOST_GUARD_WAGE'))+' credits per guard per staffed minute, debited at wage intervals')
    for offer in dm.paths('/datum/market_item'):
        path=dm.val(offer,'item'); chance=dm.val(offer,'availability_prob')
        if not path or not chance: continue
        price=dm.val(offer,'price')
        if price is None: price=f'rand({dm.val(offer,"price_min")},{dm.val(offer,"price_max")})'
        stock=dm.val(offer,'stock')
        if stock is None: stock=f'rand({dm.val(offer,"stock_min")},{dm.val(offer,"stock_max")})'
        for market in dm.val(offer,'markets') or []:
            shipping=dm.val(offer,'shipping_override') or dm.val(market,'shipping')
            add(str(dm.val(market,'name')),dm.val(offer,'name') or item_name(dm,path),dm.loc(offer),price,shop_type=market,sku_type=offer,shelf='other',item_path=path,item_name=item_name(dm,path),stock=stock,stock_min=dm.val(offer,'stock_min'),stock_max=dm.val(offer,'stock_max'),outpost='Portable black-market uplink',restock_rule='SSmarket.restock event: availability roll; existing stock +rand(1,stock_max-stock); absent types reroll if restockable',notes=f'Availability {chance}%; add shipping credits='+scalar(shipping)+'; restockable='+str(dm.val(offer,'restockable')),field_sources=f_sources(dm,offer,['item','price','price_min','price_max','stock','stock_min','stock_max','availability_prob','shipping_override']))
    add('Galactic materials market','runtime materials order',dm.loc('/datum/supply_pack/custom/minerals'),'live material ask * quantity',sku_type='/datum/supply_pack/custom/minerals',item_path='runtime permitted material sheet types',outpost='Ship cargo console / materials order console',stock='live pooled SSstock_market stock',notes='Hidden custom mineral pack accepted by valid_material_order_contents; dynamic quantity and ask, no static pack entry')
    for event in dm.paths('/datum/exploration_event/simple/trader'):
        want=dm.val(event,'required_path'); give=dm.val(event,'traded_path')
        if not want or not give: continue
        name=dm.val(event,'name')
        add('Exploration-drone trader: '+name,scalar(give),dm.loc(event),shop_type=event,sku_type=event,item_path=give,item_name=item_name(dm,give) if isinstance(give,str) else 'one random pick: '+', '.join(str(item_name(dm,p)) for p in give),other_currency={'required_path':want,'amount':1,'choice_rule':'list values choose one at event/New; consumes one matching drone-carried object'},stock=dm.val(event,'amount'),stock_max=dm.val(event,'amount'),restock_rule='none; per generated event',outpost='Exploration-drone remote site',notes='Barter, not credits. Requires translator='+str(dm.val(event,'requires_translator'))+'; site traits='+scalar(dm.val(event,'required_site_traits')))

def extra_buybacks(dm,buys):
    for event in dm.paths('/datum/exploration_event/simple/trader'):
        want=dm.val(event,'required_path'); give=dm.val(event,'traded_path')
        if not want or not give: continue
        buys.append(dict(evidence='CODE',shop='Exploration-drone trader: '+str(dm.val(event,'name')),shop_type=event,seller_npc=dm.val(event,'name'),outpost='Exploration-drone remote site',zone='not a physical overmap zone',kind='exploration-drone barter',entry_type=event,item_path=want,item_name='; '.join(str(item_name(dm,p)) for p in want) if isinstance(want,list) else item_name(dm,want),amount=1,pay_credits=0,pay_vouchers=0,other_payment={'traded_path':give,'selection':'one path selected per event at New'},demand=dm.val(event,'amount'),demand_max=dm.val(event,'amount'),refill_rule='none; generated event allowance',match_subtypes=1,source=dm.loc(event),field_sources=f_sources(dm,event,['required_path','traded_path','amount']),notes='Reverse side of corresponding catalog barter; translator/site trait gates apply'))
    # Cargo is a reference market, just as cargo.csv is a reference price list.
    # Include state-dependent functions verbatim as machine-readable CODE, rather
    # than presenting the initial base rate as an unconditional payout.
    for export in dm.paths('/datum/export'):
        types=dm.val(export,'export_types')
        if not types or dm.val(export,'sales_market') != dm.eval('EXPORT_MARKET_STATION'): continue
        if dm.is_a(export,'/datum/export/material') and not dm.val(export,'material_id'): continue
        price_procs=proc_chain(dm,export,'get_cost')
        amount_procs=proc_chain(dm,export,'get_amount')
        formula={'base_cost':dm.val(export,'cost'),'k_elasticity':dm.val(export,'k_elasticity'),'material_id':dm.val(export,'material_id'),'exclude_types':dm.val(export,'exclude_types'),'get_cost_code':[t for s,t in price_procs],'get_amount_code':[t for s,t in amount_procs]}
        # Preserve additional rule parameters used in dynamic overrides.
        for key in ['contents_cost','k_recovery_elasticity','include_subtypes','needs_discovery','allow_negative_cost']: formula[key]=dm.val(export,key)
        if dm.is_a(export,'/datum/export/large/gas_canister'): formula['get_gas_value_code']=dm.proc('/datum/export/large/gas_canister/get_gas_value')
        if dm.is_a(export,'/datum/export/material/plasma') or dm.is_a(export,'/datum/export/material/market/plasma'): formula['plasma_export_bid_code']=dm.proc('/proc/plasma_export_bid')
        buys.append(dict(evidence='CODE',shop='Cargo exports (reference)',shop_type='cargo exports',seller_npc='Cargo shuttle',outpost='Ship cargo shuttle',zone='green|yellow|red',kind='cargo export reference',entry_type=export,item_path=types,item_name=dm.val(export,'unit_name') or dm.val(export,'message'),amount='get_amount(item)',pay_credits='',pay_vouchers=0,other_payment=formula,demand='unlimited; elastic value decreases',demand_max='',refill_rule='cost *= e^(k_elasticity*k_recovery_elasticity) each SSprocessing tick; capped at init_cost',match_subtypes=dm.val(export,'include_subtypes'),source=dm.loc(export),field_sources=dict(**f_sources(dm,export,['cost','export_types','exclude_types','sales_market']),get_cost=[s for s,t in price_procs],get_amount=[s for s,t in amount_procs]),notes='First applicable export in setupExports order wins; contents recursively exported separately. Dynamic payout function is supplied, not a guessed flat price.'))
    # Other board requests are conditional services, with fixed quote functions.
    for shop in ['/datum/outpost_shop/general','/datum/outpost_shop/outfitter','/datum/outpost_shop/black_market']:
        for mission in ['/datum/mission/recovery/outpost','/datum/mission/recovery/kill/outpost','/datum/mission/outpost_courier']:
            mult=dm.val(mission,'contract_pay_mult')
            quote={'easy':f'floor(rand(600,900)*{mult})','medium':f'floor(rand(1300,1800)*{mult})','hard':f'floor(rand(2400,3200)*{mult})'}
            if '/kill/' in mission: quote={'easy':'floor(rand(600,900)*1.10)','medium':'floor(rand(1300,1800)*0.95)','hard':'floor(rand(2400,3200)*0.55)'}
            if mission.endswith('outpost_courier'): quote['ceiling']='10*Chebyshev distance to destination outpost'
            buys.append(dict(evidence='CODE',shop=dm.val(shop,'outpost_name'),shop_type=shop,seller_npc=dm.val(shop,'trader_name'),outpost=dm.val(shop,'outpost_name'),zone={'general':'green','outfitter':'yellow','black_market':'red'}[shop.split('/')[-1]],kind='service contract',entry_type=mission,item_path='bound mission proof / freight pod',item_name=dm.val(mission,'name'),amount=1,pay_credits='',pay_vouchers='',other_payment={'quote_credit_equivalent':quote},demand='4 shared mixed board offers',demand_max=4,refill_rule='11-minute board refill; 22-minute offer expiry',match_subtypes='',source=dm.loc(mission),field_sources={'quote':dm.procs['/datum/outpost_shop/roll_contract_reward'][0][0]},notes='Fixed quote; at most 60% in up to 2 available eligible core goods, remainder vouchers at 1200 and exact residual credits; not an unconditional item buyback'))
    file='voidcrew/modules/drug_smuggling/mission.dm'
    for band,mult,bonus in [('green',1,0),('yellow',1.5,0),('red',2,1)]:
        for purity in ['STREET','PURE','PRIMO']:
            factor=dm.eval('DRUG_PAYOUT_MULT_'+purity)
            low=math.floor(4000*mult*factor/10)*10; high=math.floor(5000*mult*factor/10)*10
            buys.append(dict(evidence='CODE',shop='Undertow Exchange drug handover',shop_type='/datum/outpost_shop/black_market',seller_npc='Vex (kingpin issues job)',outpost='Undertow Exchange',zone='red',kind='drug-run contract',entry_type='/datum/mission/drug_run#'+band+'/'+purity.lower(),item_path='/obj/item/drug_product',item_name='bound '+purity.lower()+' drug batch',amount=1,pay_credits=f'{low}..{high}',pay_vouchers=3+bonus+(purity=='PRIMO'),other_payment='',demand='one active run per mission limit; issued by kingpin',demand_max='',refill_rule='kingpin job lifecycle',match_subtypes='',source=dm.loc('/datum/mission/drug_run'),field_sources={'zone':dm.procs['/datum/mission/drug_run/apply_zone_scaling'][0][0],'purity':dm.procs['/datum/mission/drug_run/on_cook_finished'][0][0]},notes='Computed from base 4000..5000, pinned work band '+band+', and purity multiplier '+str(factor)+'; table band is job target, seller remains red; valid mission-bound product only'))

def annotate(dm,rows,buys):
    for b in buys:
        entry=b['entry_type']
        if b['kind']=='buyback':
            chain=proc_chain(dm,entry,'matches')
            b['match_rule']={'description':dm.val(entry,'desc'),'procedures':[{'source':s,'code':t} for s,t in chain], 'required_moles':dm.val(entry,'required_moles'),'gas_type':dm.val(entry,'gas_type'),'min_complexity':dm.val(entry,'min_complexity')}
        elif b['kind']=='cargo export reference':
            b['match_rule']={'procedures':[{'source':s,'code':t} for s,t in proc_chain(dm,entry,'applies_to')]}
    for row in rows:
        sku=row['sku_type']
        path=row['item_path']
        if isinstance(path,str) and path.startswith('/obj/item/stack'):
            row['delivered_units']=row['dispense_amount'] if row['dispense_amount']>1 else dm.val(path,'amount')
            row['field_sources']['stack_amount']=dm.field(path,'amount').source
        else: row['delivered_units']=1 if path else ''
        if isinstance(sku,str) and sku.startswith('/datum/shop_sku/'):
            if sku in ['/datum/shop_sku/general/rotating/freight_crate','/datum/shop_sku/black_market/mystery_cache','/datum/shop_sku/black_market/mystery_cache_rare']:
                row['notes']+='; zone_loot/dispense sets freight_weapons=TRUE; freight gun draws demote the red class to yellow; themed supplies remain'
            if row['shelf']=='back room': row['notes']+='; no daily special; authored discount_pct can still compete with favor'
        if sku=='/datum/shop_sku/outpost_deed': row['notes']+='; name-bound at dispense; inherited fixed_price=FALSE and contract_reward=TRUE despite full-price prose comment'

def validate(dm,rows,buys,packs):
    keys=[(r['shop_type'],r['sku_type']) for r in rows]
    assert len(keys)==len(set(keys)), 'Duplicate offer within a shop'
    for r in rows:
        if str(r['sku_type']).startswith('/datum/shop_sku'):
            for key in ['price_credits','price_vouchers','stock_min','stock_max','fixed_price','contract_reward','zone_permission','dispense_amount','crew_limit']:
                assert isinstance(r[key],(int,float)),('Unresolved SKU field',r['sku_type'],key,r[key])
            assert r['sku_name'], ('Missing display name',r['sku_type'])
    for b in buys:
        if b['kind']=='buyback':
            for key in ['pay_credits','pay_vouchers','amount','demand_max']:
                assert isinstance(b[key],(int,float)),('Unresolved buyback',b['entry_type'],key)
    for p in packs:
        if 'runtime order' not in p['pack_type']: assert isinstance(p['cost'],(int,float)), ('Unresolved cargo cost',p['pack_type'])
    line_counts={}
    for collection in [rows,buys,packs]:
        for r in collection:
            file,line=r['source'].rsplit(':',1)
            if file not in line_counts:
                line_counts[file]=len((dm.root/file).read_text(encoding='utf-8-sig').splitlines()) if (dm.root/file).exists() else 0
            assert 1 <= int(line) <= line_counts[file],r['source']

def contract_rows(dm,ctx,buys,rows):
    for r in rows:
        if not str(r.get('sku_type','')).startswith('/datum/shop_sku/barter/'): continue
        price=r['other_currency']
        buys.append(dict(evidence='CODE',shop=r['shop'],shop_type=r['shop_type'],seller_npc=r['seller_npc'],outpost=r['outpost'],zone=r['zone'],kind='barter',entry_type=r['sku_type'],item_path=price['item_path'],item_name=item_name(dm,price['item_path']),amount=price['amount'],pay_credits=0,pay_vouchers=0,other_payment={'item_path':r['item_path'],'amount':r['dispense_amount']},demand=r['stock'],demand_max=r['stock_max'],refill_rule=r['restock_rule'],match_subtypes=1,source=r['source'],field_sources=r['field_sources'],notes='Same exchange as catalog row, reverse direction; not an additional offer'))
    allowed=set(paths_in(dm.proc('/proc/is_outpost_procurement_type').split('eligible_types = list(',1)[1].split(')',1)[0]))
    for shop in ['/datum/outpost_shop/general','/datum/outpost_shop/outfitter','/datum/outpost_shop/black_market']:
        requests=[(r,shop) for r in dm.val(shop,'mission_requests') or []]
        if shop.endswith('/outfitter'): requests += [(r,'/datum/outpost_shop/vendor/suit_fitter') for r in dm.val('/datum/outpost_shop/vendor/suit_fitter','mission_requests') or []]
        for i,(data,request_shop) in enumerate(requests):
            r=dict(data); path=r['type']
            if path not in allowed: continue
            reward_shop=r.get('reward_shop',shop)
            counter=0
            for b in buys:
                if b['kind']!='buyback' or b['shop_type']!=reward_shop or not b['item_path']: continue
                if (dm.is_a(path,b['item_path']) if b['match_subtypes'] else path==b['item_path']):
                    counter=math.floor((b['pay_credits']+b['pay_vouchers']*dm.eval('VOUCHER_CREDIT_VALUE'))*r['amount']/max(1,b['amount'])); break
            if dm.is_a(path,'/obj/item/mod/module'): counter=250*r['amount']
            diff=r['difficulty']; band={dm.eval('MISSION_DIFFICULTY_EASY'):'EASY',dm.eval('MISSION_DIFFICULTY_MEDIUM'):'MEDIUM',dm.eval('MISSION_DIFFICULTY_HARD'):'HARD'}[diff]
            service=dm.eval('CONTRACT_SERVICE_'+band)
            routine=path in ['/obj/item/fish','/obj/item/stack/sheet/animalhide/bear']
            bandlo,bandhi=dm.eval('CONTRACT_PAY_'+band+'_MIN'),dm.eval('CONTRACT_PAY_'+band+'_MAX')
            if r.get('pay_min'): bandlo,bandhi=r['pay_min'],r['pay_max']
            def quote(x):
                if routine: return max(math.ceil(counter*dm.eval('CONTRACT_EXCEPTION_PREMIUM')), min(math.floor(x*dm.eval('CONTRACT_EXCEPTION_MULT')),service))
                return max(math.ceil(counter*dm.eval('CONTRACT_ASK_PREMIUM')),min(x,counter+service))
            low,high=quote(bandlo),quote(bandhi)
            quote_value=low if low==high else f'{low}..{high}'
            notes=f'Computed CODE quote; ask_value={counter} credit-equivalent from first matching reward-shop buyback (vouchers valued at 1200), or module reference 250/unit. '+('Routine: no vouchers.' if routine else 'Currency remainder: floor(remainder/1200) vouchers + exact residual credits.')
            notes+=' Up to 2 available credit-only core goods consume at most floor(quote*0.6); remaining quote paid as currency; denied goods become exact-value remainder. reward_shop='+reward_shop
            buys.append(dict(evidence='CODE',shop=dm.val(shop,'outpost_name'),shop_type=shop,seller_npc=dm.val(request_shop,'trader_name'),outpost=ctx[shop][0],zone=ctx[shop][1],kind='supply contract',entry_type=f'/datum/mission/outpost_supply#{i+1}',item_path=path,item_name=r['name'],amount=r['amount'],pay_credits='',pay_vouchers='',other_payment={'quote_credit_equivalent':quote_value,'ask_value':counter,'difficulty':band.lower(),'routine':routine},demand='shared board: 4 total mixed offers',demand_max=4,refill_rule='vacancies filled every 11 minutes; unaccepted offers expire at 22 minutes',match_subtypes=0 if dm.is_a(path,'/obj/item/mod/module') else 1,source=dm.field(request_shop,'mission_requests').source,field_sources={'valuation':dm.procs['/datum/outpost_shop/get_counter_value'][0][0],'quote':dm.procs['/datum/outpost_shop/roll_contract_reward'][0][0]},notes=notes))
    file='voidcrew/modules/trade/outpost_missions.dm'
    for flavor,listname,path in [('angler','fish_asks','/obj/item/fish'),('cook','cook_asks','/obj/item/food')]:
        text=dm.proc('/datum/mission/outpost_supply/'+flavor+'/pick_request')
        raw=text.split(listname+' = list(',1)[1].split('\n\t)',1)[0]
        asks=dm.eval('list('+raw+')')
        for i,data in enumerate(asks):
            ask=dict(data); band={dm.eval('MISSION_DIFFICULTY_EASY'):'easy',dm.eval('MISSION_DIFFICULTY_MEDIUM'):'medium',dm.eval('MISSION_DIFFICULTY_HARD'):'hard'}[ask['difficulty']]
            # Both are routine, ask valuation is fish buyback * quantity or 0 for cooking.
            counter=0
            if flavor=='angler':
                b=next(b for b in buys if b['shop_type']=='/datum/outpost_shop/general' and b['item_path']==path and b['kind']=='buyback')
                counter=math.floor(b['pay_credits']*ask['amount']/b['amount'])
            quote=max(math.ceil(counter*1.1),min(math.floor(dm.eval('CONTRACT_PAY_'+band.upper()+'_MIN')*.4),dm.eval('CONTRACT_SERVICE_'+band.upper())))
            buys.append(dict(evidence='CODE',shop='Waystation Halcyon contract board',shop_type='/datum/outpost_shop/general',seller_npc='Pike' if flavor=='angler' else 'Roux',outpost=ctx['/datum/outpost_shop/general'][0],zone='green',kind=flavor+' contract',entry_type=f'/datum/mission/outpost_supply/{flavor}#{i+1}',item_path=path,item_name=ask['name'],amount=ask['amount'],pay_credits='',pay_vouchers=0,other_payment={'quote_credit_equivalent':quote,'ask_value':counter},demand='shared board: 4 mixed offers',demand_max=4,refill_rule='11-minute board refill; 22-minute offer expiry',match_subtypes=1,source=dm.cite(file,'var/static/list/'+listname),field_sources={},notes='Computed routine quote; core-goods package plus credit remainder; request constraints='+scalar(ask)))


def as_text(rows, fields):
    """The flat shape: one text cell per field. A row with a field nothing declared is a bug, so it raises."""
    flat = []
    for row in rows:
        extra = set(row) - set(fields)
        if extra:
            raise ValueError(f'undeclared fields {sorted(extra)}')
        flat.append({k: str(scalar(row.get(k))) for k in fields})
    return flat


def load_offers(dm):
    """Returns (shop and service offers, buybacks, cargo packs, cargo packs the console refuses by reason)."""
    ctx = contexts(dm)
    rows, buys, _ = catalog(dm, ctx)
    extra_catalog(dm, rows)
    contract_rows(dm, ctx, buys, rows)
    extra_buybacks(dm, buys)
    packs, rejected = cargo(dm)
    annotate(dm, rows, buys)
    validate(dm, rows, buys, packs)
    return as_text(rows, CAT_FIELDS), as_text(buys, BUY_FIELDS), as_text(packs, CARGO_FIELDS), rejected
