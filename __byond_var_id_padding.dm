// BYOND bug workaround (VOIDCREW): DM numbers every variable name from one table, and a proc static,
// global or local that lands on id 65535 compiles wrong. A static or global fails with "<name>: invalid
// variable", and a local gets a false "variable defined but not used" warning and reads the wrong value.
// Object vars and proc arguments on that id are fine. Once a build has more than 65535 names, about half
// of all changes put some static or local on the broken id. Seen on 516.1659 and 516.1667.
//
// This file is included first, so its 70,000 unused var names take ids 0 to 69999, and id 65535 always
// falls on one of them. A type holds at most about 65k vars, so they are split over seven subtypes.
// Nothing ever makes a /datum/byond_var_id_padding. Remove this once BYOND fixes it.

#define VAR_ID_PAD_1(a, b, c, d, e) var/var_id_pad_##a##b##c##d##e
#define VAR_ID_PAD_10(a, b, c, d) VAR_ID_PAD_1(a, b, c, d, 0);VAR_ID_PAD_1(a, b, c, d, 1);VAR_ID_PAD_1(a, b, c, d, 2);VAR_ID_PAD_1(a, b, c, d, 3);VAR_ID_PAD_1(a, b, c, d, 4);VAR_ID_PAD_1(a, b, c, d, 5);VAR_ID_PAD_1(a, b, c, d, 6);VAR_ID_PAD_1(a, b, c, d, 7);VAR_ID_PAD_1(a, b, c, d, 8);VAR_ID_PAD_1(a, b, c, d, 9)
#define VAR_ID_PAD_100(a, b, c) VAR_ID_PAD_10(a, b, c, 0);VAR_ID_PAD_10(a, b, c, 1);VAR_ID_PAD_10(a, b, c, 2);VAR_ID_PAD_10(a, b, c, 3);VAR_ID_PAD_10(a, b, c, 4);VAR_ID_PAD_10(a, b, c, 5);VAR_ID_PAD_10(a, b, c, 6);VAR_ID_PAD_10(a, b, c, 7);VAR_ID_PAD_10(a, b, c, 8);VAR_ID_PAD_10(a, b, c, 9)
#define VAR_ID_PAD_1000(a, b) VAR_ID_PAD_100(a, b, 0);VAR_ID_PAD_100(a, b, 1);VAR_ID_PAD_100(a, b, 2);VAR_ID_PAD_100(a, b, 3);VAR_ID_PAD_100(a, b, 4);VAR_ID_PAD_100(a, b, 5);VAR_ID_PAD_100(a, b, 6);VAR_ID_PAD_100(a, b, 7);VAR_ID_PAD_100(a, b, 8);VAR_ID_PAD_100(a, b, 9)

/datum/byond_var_id_padding

/datum/byond_var_id_padding/part_0
	VAR_ID_PAD_1000(0, 0)
	VAR_ID_PAD_1000(0, 1)
	VAR_ID_PAD_1000(0, 2)
	VAR_ID_PAD_1000(0, 3)
	VAR_ID_PAD_1000(0, 4)
	VAR_ID_PAD_1000(0, 5)
	VAR_ID_PAD_1000(0, 6)
	VAR_ID_PAD_1000(0, 7)
	VAR_ID_PAD_1000(0, 8)
	VAR_ID_PAD_1000(0, 9)

/datum/byond_var_id_padding/part_1
	VAR_ID_PAD_1000(1, 0)
	VAR_ID_PAD_1000(1, 1)
	VAR_ID_PAD_1000(1, 2)
	VAR_ID_PAD_1000(1, 3)
	VAR_ID_PAD_1000(1, 4)
	VAR_ID_PAD_1000(1, 5)
	VAR_ID_PAD_1000(1, 6)
	VAR_ID_PAD_1000(1, 7)
	VAR_ID_PAD_1000(1, 8)
	VAR_ID_PAD_1000(1, 9)

/datum/byond_var_id_padding/part_2
	VAR_ID_PAD_1000(2, 0)
	VAR_ID_PAD_1000(2, 1)
	VAR_ID_PAD_1000(2, 2)
	VAR_ID_PAD_1000(2, 3)
	VAR_ID_PAD_1000(2, 4)
	VAR_ID_PAD_1000(2, 5)
	VAR_ID_PAD_1000(2, 6)
	VAR_ID_PAD_1000(2, 7)
	VAR_ID_PAD_1000(2, 8)
	VAR_ID_PAD_1000(2, 9)

/datum/byond_var_id_padding/part_3
	VAR_ID_PAD_1000(3, 0)
	VAR_ID_PAD_1000(3, 1)
	VAR_ID_PAD_1000(3, 2)
	VAR_ID_PAD_1000(3, 3)
	VAR_ID_PAD_1000(3, 4)
	VAR_ID_PAD_1000(3, 5)
	VAR_ID_PAD_1000(3, 6)
	VAR_ID_PAD_1000(3, 7)
	VAR_ID_PAD_1000(3, 8)
	VAR_ID_PAD_1000(3, 9)

/datum/byond_var_id_padding/part_4
	VAR_ID_PAD_1000(4, 0)
	VAR_ID_PAD_1000(4, 1)
	VAR_ID_PAD_1000(4, 2)
	VAR_ID_PAD_1000(4, 3)
	VAR_ID_PAD_1000(4, 4)
	VAR_ID_PAD_1000(4, 5)
	VAR_ID_PAD_1000(4, 6)
	VAR_ID_PAD_1000(4, 7)
	VAR_ID_PAD_1000(4, 8)
	VAR_ID_PAD_1000(4, 9)

/datum/byond_var_id_padding/part_5
	VAR_ID_PAD_1000(5, 0)
	VAR_ID_PAD_1000(5, 1)
	VAR_ID_PAD_1000(5, 2)
	VAR_ID_PAD_1000(5, 3)
	VAR_ID_PAD_1000(5, 4)
	VAR_ID_PAD_1000(5, 5)
	VAR_ID_PAD_1000(5, 6)
	VAR_ID_PAD_1000(5, 7)
	VAR_ID_PAD_1000(5, 8)
	VAR_ID_PAD_1000(5, 9)

/datum/byond_var_id_padding/part_6
	VAR_ID_PAD_1000(6, 0)
	VAR_ID_PAD_1000(6, 1)
	VAR_ID_PAD_1000(6, 2)
	VAR_ID_PAD_1000(6, 3)
	VAR_ID_PAD_1000(6, 4)
	VAR_ID_PAD_1000(6, 5)
	VAR_ID_PAD_1000(6, 6)
	VAR_ID_PAD_1000(6, 7)
	VAR_ID_PAD_1000(6, 8)
	VAR_ID_PAD_1000(6, 9)

#undef VAR_ID_PAD_1000
#undef VAR_ID_PAD_100
#undef VAR_ID_PAD_10
#undef VAR_ID_PAD_1
