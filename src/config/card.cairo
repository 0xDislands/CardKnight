use card_knight::models::card::CardIdEnum;

// Monsters
const MONSTER1_BASE_HP: u32 = 5;
const MONSTER1_MULTIPLE: u32 = 2;
const MONSTER2_BASE_HP: u32 = 10;
const MONSTER2_MULTIPLE: u32 = 3;
const MONSTER3_BASE_HP: u32 = 20;
const MONSTER3_MULTIPLE: u32 = 4;

// Boss
const BOSS_BASE_HP: u32 = 50;
const BOSS_MULTIPLE: u32 = 5;

// Heal & Shield
const HEAL_HP: u32 = 5;
const SHIELD_HP: u32 = 5;
const POISON_TURN: u32 = 3;

//XPs
const HEAL_XP: u32 = 0;
const POISON_XP: u32 = 0;
const MONSTER1_XP: u32 = 1;
const MONSTER2_XP: u32 = 1;
const MONSTER3_XP: u32 = 2;
const BOSS_XP: u32 = 3;
const SHIELD_XP: u32 = 0;
const CHEST_XP: u32 = 1;

// Tags
const INCREASE_HP_RATIO: u32 = 20; // %20


fn card_sequence() -> Array::<CardIdEnum> {
    let mut card_sequence = ArrayTrait::<CardIdEnum>::new();
    card_sequence.append(CardIdEnum::Monster1);
    card_sequence.append(CardIdEnum::ItemHeal);
    card_sequence.append(CardIdEnum::Monster2);
    card_sequence.append(CardIdEnum::ItemPoison);
    card_sequence.append(CardIdEnum::Monster3);
    card_sequence.append(CardIdEnum::ItemChest);
    card_sequence.append(CardIdEnum::Monster1);
    card_sequence.append(CardIdEnum::ItemHeal);
    card_sequence.append(CardIdEnum::Monster2);
    card_sequence.append(CardIdEnum::ItemChestMiniGame);
    card_sequence.append(CardIdEnum::Monster3);
    card_sequence.append(CardIdEnum::ItemChestEvil);
    card_sequence.append(CardIdEnum::Monster1);
    card_sequence.append(CardIdEnum::ItemShield);
    card_sequence.append(CardIdEnum::Monster2);
    card_sequence.append(CardIdEnum::Boss1);
    card_sequence.append(CardIdEnum::ItemChestEvil);
    card_sequence.append(CardIdEnum::Monster1);
    card_sequence.append(CardIdEnum::ItemHeal);
    card_sequence.append(CardIdEnum::Monster2);
    card_sequence.append(CardIdEnum::ItemChestMiniGame);
    card_sequence.append(CardIdEnum::Monster3);
    card_sequence.append(CardIdEnum::ItemChestEvil);
    card_sequence
}
