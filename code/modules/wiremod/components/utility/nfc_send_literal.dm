/**
 * # NFC Transmitter List Literal Component
 *
 * Create a list literal and send a data package through NFC
 *
 * This file is based off of nfc_sendl.dm
 * Any changes made to those files should be copied over with discretion
 */
/obj/item/circuit_component/list_literal/nfc_send
	display_name = "NFC Transmitter List Literal"
	desc = "Creates a list literal data package and sends it through NFC. If Encryption Key is set then transmitted data will be only picked up by receivers with the same Encryption Key."
	category = "Utility"

	/// Encryption key
	var/datum/port/input/enc_key

	/// The targeted circuit
	var/datum/port/input/target

/obj/item/circuit_component/list_literal/nfc_send/populate_ports()
	. = ..()
	enc_key = add_input_port("Encryption Key", PORT_TYPE_STRING)
	target = add_input_port("Target", PORT_TYPE_ATOM)

// Voidcrew: this used to gate on find_functional_ntnet_relay(). NFC is a direct point to point
// link that never touched NTNet, and the fork has no relays at all, so the gate did nothing but
// keep the component permanently dead. The plain component check is the whole requirement.

/obj/item/circuit_component/list_literal/nfc_send/input_received(datum/port/input/port)
	. = ..()
	if(isatom(target.value))
		var/atom/target_enty = target.value
		// Voidcrew: the sending circuit was missing from this signal, so nfc_receive() read the
		// payload list as its `sender` argument and the real payload as null - the list literal
		// variant could never deliver anything. nfc_send.dm has always passed it.
		SEND_SIGNAL(target_enty, COMSIG_CIRCUIT_NFC_DATA_SENT, parent, list("data" = list_output.value, "enc_key" = enc_key.value, "port" = WEAKREF(list_output)))
