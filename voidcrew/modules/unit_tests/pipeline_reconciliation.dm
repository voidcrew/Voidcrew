/// Reconciliation may reach a shared mix through more than one connected port.
/datum/unit_test/pipeline_reconciliation/Run()
	var/datum/pipeline/network = allocate(/datum/pipeline)
	var/datum/gas_mixture/first = allocate(/datum/gas_mixture)
	var/datum/gas_mixture/second = allocate(/datum/gas_mixture)
	first.volume = 100
	second.volume = 200
	first.temperature = 300
	second.temperature = 600
	ASSERT_GAS(/datum/gas/oxygen, first)
	ASSERT_GAS(/datum/gas/nitrogen, second)
	first.gases[/datum/gas/oxygen][MOLES] = 10
	second.gases[/datum/gas/nitrogen][MOLES] = 20
	var/initial_energy = first.thermal_energy() + second.thermal_energy()
	network.air = first
	network.other_airs = list(second, second)
	network.reconcile_air()
	TEST_ASSERT(abs(first.total_moles() - 10) < 0.001, "Duplicate connection changed the first volume's share")
	TEST_ASSERT(abs(second.total_moles() - 20) < 0.001, "Duplicate connection changed the second volume's share")
	TEST_ASSERT(abs(first.gases[/datum/gas/oxygen][MOLES] + second.gases[/datum/gas/oxygen][MOLES] - 10) < 0.001, "Reconciliation lost or created oxygen")
	TEST_ASSERT(abs(first.gases[/datum/gas/nitrogen][MOLES] + second.gases[/datum/gas/nitrogen][MOLES] - 20) < 0.001, "Reconciliation lost or created nitrogen")
	TEST_ASSERT(abs(first.temperature - second.temperature) < 0.001, "Duplicate connection prevented thermal equilibrium")
	TEST_ASSERT(abs(first.thermal_energy() + second.thermal_energy() - initial_energy) < initial_energy * 0.0001, "Reconciliation changed total thermal energy")

/// A removed port may leave an absent mix while the shared network is rebuilding.
/datum/unit_test/pipeline_reconciliation_missing_mix/Run()
	var/datum/pipeline/network = allocate(/datum/pipeline)
	var/datum/gas_mixture/first = allocate(/datum/gas_mixture)
	var/datum/gas_mixture/second = allocate(/datum/gas_mixture)
	first.volume = 100
	second.volume = 100
	first.temperature = 300
	second.temperature = 300
	ASSERT_GAS(/datum/gas/oxygen, first)
	first.gases[/datum/gas/oxygen][MOLES] = 20
	network.air = first
	network.other_airs = list(null, second)
	network.reconcile_air()
	TEST_ASSERT(abs(first.total_moles() - 10) < 0.001, "Missing mix interrupted valid gas distribution")
	TEST_ASSERT(abs(second.total_moles() - 10) < 0.001, "Missing mix prevented the connected volume from receiving gas")
