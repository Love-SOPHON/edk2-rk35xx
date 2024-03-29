/** @file
*  USB2 devices.
*
*  Copyright (c) 2022, Jared McNeill <jmcneill@invisible.ca>
*
*  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <IndustryStandard/Acpi64.h>

// USB OHCI Host Controller
Device (OHC0) {
    Name (_HID, "PRP0001")
    Name (_CLS, Package() { 0x0c, 0x03, 0x10 })
    Name (_UID, Zero)
    Name (_CCA, Zero)

    Name (_DSD, Package () {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package () {
            Package () { "compatible", "generic-ohci" },
        }
    })

    Method (_CRS, 0x0, Serialized) {
        Name (RBUF, ResourceTemplate() {
            Memory32Fixed (ReadWrite, 0xFD840000, 0x40000)
            Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 163 }
        })
        Return (RBUF)
    }

    Name (_STA, FixedPcdGet8(PcdOhc0Status))

    Device (RHUB) {
        Name (_ADR, 0)
        Device (PRT1) {
            Name (_ADR, 1)
            Name (_UPC, Package() {
                0xFF,         // Port is connectable
                0x00,         // Connector type - Type 'A'
                0x00000000,   // Reserved, must be zero
                0x00000000    // Reserved, must be zero
            })
            Name (_PLD, Package (0x01) {
                ToPLD (
                PLD_Revision            = 0x2,
                PLD_IgnoreColor         = 0x1,
                PLD_UserVisible         = 0x1,
                PLD_Panel               = "UNKNOWN",
                PLD_VerticalPosition    = "UPPER",
                PLD_HorizontalPosition  = "LEFT",
                PLD_Shape               = "HORIZONTALRECTANGLE",
                PLD_Ejectable           = 0x1,
                PLD_EjectRequired       = 0x1,
                )
            })
        } // PRT1
    } // RHUB
} // OHC0

// USB EHCI Host Controller
Device (EHC0) {
    Name (_HID, "PNP0D20")
    Name (_UID, Zero)
    Name (_CCA, Zero)

    Method (_CRS, 0x0, Serialized) {
        Name (RBUF, ResourceTemplate() {
            Memory32Fixed (ReadWrite, 0xFD800000, 0x40000)
            Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 162 }
        })
        Return (RBUF)
    }

    Name (_STA, FixedPcdGet8(PcdEhc0Status))

    // Device (RHUB) {
    //     Name (_ADR, 0)
    //     Device (PRT1) {
    //         Name (_ADR, 1)
    //         Name (_UPC, Package() {
    //         0xFF,         // Port is connectable
    //         0x00,         // Connector type - Type 'A'
    //         0x00000000,   // Reserved, must be zero
    //         0x00000000    // Reserved, must be zero
    //         })
    //         Name (_PLD, Package (0x01) {
    //         ToPLD (
    //             PLD_Revision            = 0x2,
    //             PLD_IgnoreColor         = 0x1,
    //             PLD_UserVisible         = 0x1,
    //             PLD_Panel               = "UNKNOWN",
    //             PLD_VerticalPosition    = "UPPER",
    //             PLD_HorizontalPosition  = "LEFT",
    //             PLD_Shape               = "HORIZONTALRECTANGLE",
    //             PLD_Ejectable           = 0x1,
    //             PLD_EjectRequired       = 0x1,
    //         )
    //         })
    //     } // PRT1
    // } // RHUB
        Device(RHUB){
            Name(_ADR, 0x00000000)  // Address of Root Hub should be 0 as per ACPI 5.0 spec

            //
            // Ports connected to Root Hub
            //
            Device(HUB1){
                Name(_ADR, 0x00000001)
                Name(_UPC, Package(){
                    0x00,       // Port is NOT connectable
                    0xFF,       // Don't care
                    0x00000000, // Reserved 0 must be zero
                    0x00000000  // Reserved 1 must be zero
                })

                Device(PRT1){
                    Name(_ADR, 0x00000001)
                    Name(_UPC, Package(){
                        0xFF,        // Port is connectable
                        0x00,        // Port connector is A
                        0x00000000,
                        0x00000000
                    })
                    Name(_PLD, Package(){
                        Buffer(0x10){
                            0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    })
                } // USB0_RHUB_HUB1_PRT1
                Device(PRT2){
                    Name(_ADR, 0x00000002)
                    Name(_UPC, Package(){
                        0xFF,        // Port is connectable
                        0x00,        // Port connector is A
                        0x00000000,
                        0x00000000
                    })
                    Name(_PLD, Package(){
                        Buffer(0x10){
                            0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    })
                } // USB0_RHUB_HUB1_PRT2

                Device(PRT3){
                    Name(_ADR, 0x00000003)
                    Name(_UPC, Package(){
                        0xFF,        // Port is connectable
                        0x00,        // Port connector is A
                        0x00000000,
                        0x00000000
                    })
                    Name(_PLD, Package(){
                        Buffer(0x10){
                            0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    })
                } // USB0_RHUB_HUB1_PRT3

                Device(PRT4){
                    Name(_ADR, 0x00000004)
                    Name(_UPC, Package(){
                        0xFF,        // Port is connectable
                        0x00,        // Port connector is A
                        0x00000000,
                        0x00000000
                    })
                    Name(_PLD, Package(){
                        Buffer(0x10){
                            0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    })
                } // USB0_RHUB_HUB1_PRT4
            } // USB0_RHUB_HUB1
        } // USB0_RHUB

} // EHC0

// USB OHCI Host Controller
Device (OHC1) {
    Name (_HID, "PRP0001")
    Name (_CLS, Package() { 0x0c, 0x03, 0x10 })
    Name (_UID, One)
    Name (_CCA, Zero)

    Name (_DSD, Package () {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"),
        Package () {
            Package () { "compatible", "generic-ohci" },
        }
    })

    Method (_CRS, 0x0, Serialized) {
        Name (RBUF, ResourceTemplate() {
            Memory32Fixed (ReadWrite, 0xFD8C0000, 0x40000)
            Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 166 }
        })
        Return (RBUF)
    }

    Name (_STA, FixedPcdGet8(PcdOhc1Status))

    Device (RHUB) {
        Name (_ADR, 0)
        Device (PRT1) {
            Name (_ADR, 1)
            Name (_UPC, Package() {
                0xFF,         // Port is connectable
                0x00,         // Connector type - Type 'A'
                0x00000000,   // Reserved, must be zero
                0x00000000    // Reserved, must be zero
            })
            Name (_PLD, Package (0x01) {
                ToPLD (
                PLD_Revision            = 0x2,
                PLD_IgnoreColor         = 0x1,
                PLD_UserVisible         = 0x1,
                PLD_Panel               = "UNKNOWN",
                PLD_VerticalPosition    = "LOWER",
                PLD_HorizontalPosition  = "LEFT",
                PLD_Shape               = "HORIZONTALRECTANGLE",
                PLD_Ejectable           = 0x1,
                PLD_EjectRequired       = 0x1,
                )
            })
        } // PRT1
    } // RHUB
} // OHC1

// USB EHCI Host Controller
Device (EHC1) {
    Name (_HID, "PNP0D20")
    Name (_UID, One)
    Name (_CCA, Zero)

    Method (_CRS, 0x0, Serialized) {
        Name (RBUF, ResourceTemplate() {
            Memory32Fixed (ReadWrite, 0xFD880000, 0x40000)
            Interrupt (ResourceConsumer, Level, ActiveHigh, Exclusive) { 165 }
        })
        Return (RBUF)
    }

    Name (_STA, FixedPcdGet8(PcdEhc1Status))

    // Device (RHUB) {
    //     Name (_ADR, 0)
    //     Device (PRT1) {
    //         Name (_ADR, 1)
    //         Name (_UPC, Package() {
    //             0xFF,         // Port is connectable
    //             0x00,         // Connector type - Type 'A'
    //             0x00000000,   // Reserved, must be zero
    //             0x00000000    // Reserved, must be zero
    //         })
    //         Name (_PLD, Package (0x01) {
    //             ToPLD (
    //             PLD_Revision            = 0x2,
    //             PLD_IgnoreColor         = 0x1,
    //             PLD_UserVisible         = 0x1,
    //             PLD_Panel               = "UNKNOWN",
    //             PLD_VerticalPosition    = "LOWER",
    //             PLD_HorizontalPosition  = "LEFT",
    //             PLD_Shape               = "HORIZONTALRECTANGLE",
    //             PLD_Ejectable           = 0x1,
    //             PLD_EjectRequired       = 0x1,
    //             )
    //         })
    //     } // PRT1
    // } // RHUB

        Device(RHUB){
            Name(_ADR, 0x00000000)  // Address of Root Hub should be 0 as per ACPI 5.0 spec

            //
            // Ports connected to Root Hub
            //
            Device(HUB1){
                Name(_ADR, 0x00000001)
                Name(_UPC, Package(){
                    0x00,       // Port is NOT connectable
                    0xFF,       // Don't care
                    0x00000000, // Reserved 0 must be zero
                    0x00000000  // Reserved 1 must be zero
                })

                Device(PRT1){
                    Name(_ADR, 0x00000001)
                    Name(_UPC, Package(){
                        0xFF,        // Port is connectable
                        0x00,        // Port connector is A
                        0x00000000,
                        0x00000000
                    })
                    Name(_PLD, Package(){
                        Buffer(0x10){
                            0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    })
                } // USB0_RHUB_HUB1_PRT1
                Device(PRT2){
                    Name(_ADR, 0x00000002)
                    Name(_UPC, Package(){
                        0xFF,        // Port is connectable
                        0x00,        // Port connector is A
                        0x00000000,
                        0x00000000
                    })
                    Name(_PLD, Package(){
                        Buffer(0x10){
                            0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    })
                } // USB0_RHUB_HUB1_PRT2

                Device(PRT3){
                    Name(_ADR, 0x00000003)
                    Name(_UPC, Package(){
                        0xFF,        // Port is connectable
                        0x00,        // Port connector is A
                        0x00000000,
                        0x00000000
                    })
                    Name(_PLD, Package(){
                        Buffer(0x10){
                            0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    })
                } // USB0_RHUB_HUB1_PRT3

                Device(PRT4){
                    Name(_ADR, 0x00000004)
                    Name(_UPC, Package(){
                        0xFF,        // Port is connectable
                        0x00,        // Port connector is A
                        0x00000000,
                        0x00000000
                    })
                    Name(_PLD, Package(){
                        Buffer(0x10){
                            0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                        }
                    })
                } // USB0_RHUB_HUB1_PRT4
            } // USB0_RHUB_HUB1
        } // USB0_RHUB

} // EHC1