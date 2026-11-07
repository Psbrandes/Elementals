class_name EnemyData
extends Resource
## Arquétipo de inimigo. Variantes por troca de paleta são só outro .tres com
## outra cor (e, se quiser, números um pouco diferentes).

## Como o inimigo cerca e ataca (ver enemy.gd).
enum Behavior { BRAWLER, RUNNER, TANK, SHOOTER, BOSS, GUARD, BOMBER }

@export var display_name := "Capanga"
@export var behavior := Behavior.BRAWLER
@export var max_hp := 30
@export var score := 100
@export var body_color := Color("6b8f3a")
## Hurtbox e retângulo placeholder: largura x altura.
@export var body_size := Vector2(20.0, 48.0)
## Pixels por segundo: x horizontal, y profundidade.
@export var walk_speed := Vector2(55.0, 35.0)
## Golpes leves que aguenta sem entrar em hit stun.
@export var armor_hits := 0
@export var grabbable := true

## Elemento do inimigo ("" = neutro). Só aparece no HUD; quem decide o dano é
## weak_to/resists.
@export var element := ""
## Elementos de herói que tiram 1,5x de dano (e quebram armadura com golpe que derruba).
@export var weak_to: PackedStringArray = []
## Elementos de herói que tiram só 0,75x de dano.
@export var resists: PackedStringArray = []
## Chance (0 a 1) de sair da faixa quando o jogador começa um golpe na direção dele.
@export var dodge_chance := 0.0
## Script próprio do inimigo (estende Enemy ou Boss), para quem tem golpes que os
## arquétipos não cobrem: Sombra, Curandeira e Corrosão, da fase 2. Vazio = enemy.gd
## (ou boss.gd, com behavior BOSS).
@export var custom_script: Script
## Golpes seguidos do soco: depois de acertar, emenda mais (Brigão = 2).
@export var combo_hits := 1
## Item que pode cair quando morre ("" = nada) e a chance.
@export var drop := ""
@export var drop_chance := 0.0

@export_group("Arte")
## Personagem em assets/characters (vazio = placeholder de blocos).
@export var sprite_id := ""
@export var sprite_scale := 0.65
## Variante de paleta: tinge a arte (branco = cores originais).
@export var sprite_tint := Color.WHITE
## Animação do soco comum.
@export var attack_anim := "atk1"
## Arte do projétil (vazio = pedra).
@export var shot_art := ""

@export_group("Soco")
@export var attack_damage := 5
@export var attack_reach := 24.0
## Quadros de antecipação: o "!" amarelo fica visível durante esse tempo.
@export var attack_startup := 14
@export var attack_active := 3
@export var attack_recovery := 22
## Espera aleatória entre um ataque e outro, em quadros.
@export var attack_cooldown_min := 50
@export var attack_cooldown_max := 100
## O soco derruba (golpe pesado, como o do Guardião de Gelo).
@export var attack_knockdown := false

@export_group("Investida (TANK)")
@export var charge_damage := 15
@export var charge_speed := 160.0
@export var charge_startup := 20
@export var charge_frames := 40
@export var charge_recovery := 40

@export_group("Pedra (SHOOTER)")
@export var shot_damage := 6
@export var shot_speed := 150.0
## Quadros entre uma pedra e outra (120 = 2 s).
@export var shot_interval := 120
@export var keep_distance := 130.0
@export var flee_distance := 56.0

@export_group("Bomba (BOMBER)")
## Quadros de voo da bomba; o alvo é marcado no chão durante o voo.
@export var bomb_flight := 50
@export var bomb_damage := 12
@export var bomb_radius := 22.0

@export_group("Escudo (GUARD)")
## Golpes de frente que segura antes de revidar com o escudo.
@export var guard_hits := 3
@export var bash_damage := 8

@export_group("Chefe (BOSS)")
@export var phase_two_color := Color("d2691e")
## Faixa que aparece quando o chefe chega (vazio = nome do Ferrugem, da fase 1).
@export var boss_title := ""
