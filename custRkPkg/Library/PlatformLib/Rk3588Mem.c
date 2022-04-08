/** @file
 *
 *  Copyright (c) 2021, Jared McNeill <jmcneill@invisible.ca>
 *  Copyright (c) 2017-2021, Andrey Warkentin <andrey.warkentin@gmail.com>
 *  Copyright (c) 2019, Pete Batard <pete@akeo.ie>
 *  Copyright (c) 2014, Linaro Limited. All rights reserved.
 *  Copyright (c) 2013-2018, ARM Limited. All rights reserved.
 *
 *  SPDX-License-Identifier: BSD-2-Clause-Patent
 *
 **/

#include <Library/ArmPlatformLib.h>
#include <Library/DebugLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/PcdLib.h>
#include <Library/Rk356xMem.h>
#include <Library/SdramLib.h>
#include <IndustryStandard/Rk35xx.h>

UINT64 mSystemMemoryBase = FixedPcdGet64 (PcdSystemMemoryBase);
STATIC UINT64 mSystemMemorySize = FixedPcdGet64 (PcdSystemMemorySize);

// The total number of descriptors, including the final "end-of-table" descriptor.
#define MAX_VIRTUAL_MEMORY_MAP_DESCRIPTORS 10

STATIC BOOLEAN                     VirtualMemoryInfoInitialized = FALSE;
STATIC RK356X_MEMORY_REGION_INFO   VirtualMemoryInfo[MAX_VIRTUAL_MEMORY_MAP_DESCRIPTORS];

/**
  Return the Virtual Memory Map of your platform

  This Virtual Memory Map is used by MemoryInitPei Module to initialize the MMU
  on your platform.

  @param[out]   VirtualMemoryMap    Array of ARM_MEMORY_REGION_DESCRIPTOR
                                    describing a Physical-to-Virtual Memory
                                    mapping. This array must be ended by a
                                    zero-filled entry

**/
VOID
ArmPlatformGetVirtualMemoryMap (
  IN ARM_MEMORY_REGION_DESCRIPTOR** VirtualMemoryMap
  )
{
  UINTN                         Index = 0;
  ARM_MEMORY_REGION_DESCRIPTOR  *VirtualMemoryTable;

  mSystemMemorySize = SdramGetMemorySize ();

  DEBUG ((DEBUG_INFO, "RAM: 0x%ll08X (Size 0x%ll08X)\n", mSystemMemoryBase, mSystemMemorySize));

  VirtualMemoryTable = (ARM_MEMORY_REGION_DESCRIPTOR*)AllocatePages
                       (EFI_SIZE_TO_PAGES (sizeof (ARM_MEMORY_REGION_DESCRIPTOR) *
                       MAX_VIRTUAL_MEMORY_MAP_DESCRIPTORS));
  if (VirtualMemoryTable == NULL) {
    return;
  }

  // MMIO
  VirtualMemoryTable[Index].PhysicalBase    = FixedPcdGet64 (PcdReservedBaseAddress);
  VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
  VirtualMemoryTable[Index].Length          = FixedPcdGet32 (PcdReservedSize);
  VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_DEVICE;
  VirtualMemoryInfo[Index].Type             = RK356X_MEM_UNMAPPED_REGION;
  VirtualMemoryInfo[Index++].Name           = L"Reserved";

  // MMIO > 32GB
  VirtualMemoryTable[Index].PhysicalBase    = 0x0000000900000000UL;
  VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
  VirtualMemoryTable[Index].Length          = 0x0000000141400000UL;
  VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_DEVICE;
  VirtualMemoryInfo[Index].Type             = RK356X_MEM_UNMAPPED_REGION;
  VirtualMemoryInfo[Index++].Name           = L"Reserved > 4GB";

  // Base System RAM
  VirtualMemoryTable[Index].PhysicalBase    = mSystemMemoryBase;
  VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
  VirtualMemoryTable[Index].Length          = MIN (mSystemMemorySize, 0xF0000000UL);
  VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_WRITE_BACK;
  VirtualMemoryInfo[Index].Type             = RK356X_MEM_BASIC_REGION;
  VirtualMemoryInfo[Index++].Name           = L"System RAM";

  if (mSystemMemoryBase + mSystemMemorySize > 0x100000000UL) {
    // Base System RAM > 4GB
    VirtualMemoryTable[Index].PhysicalBase    = 0x100000000;
    VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
    VirtualMemoryTable[Index].Length          = mSystemMemoryBase + mSystemMemorySize - 0x100000000;
    VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_WRITE_BACK;
    VirtualMemoryInfo[Index].Type             = RK356X_MEM_BASIC_REGION;
    VirtualMemoryInfo[Index++].Name           = L"System RAM > 4GB";
  }

  // TF-A Region.
  VirtualMemoryTable[Index].PhysicalBase    = FixedPcdGet64 (PcdTfaBaseAddress);
  VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
  VirtualMemoryTable[Index].Length          = FixedPcdGet32 (PcdTfaSize);
  VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_UNCACHED_UNBUFFERED;
  VirtualMemoryInfo[Index].Type             = RK356X_MEM_RESERVED_REGION;
  VirtualMemoryInfo[Index++].Name           = L"TF-A";

  // OP-TEE Region.
  VirtualMemoryTable[Index].PhysicalBase    = FixedPcdGet64 (PcdOpteeBaseAddress);
  VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
  VirtualMemoryTable[Index].Length          = FixedPcdGet32 (PcdOpteeSize);
  VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_WRITE_BACK;
  VirtualMemoryInfo[Index].Type             = RK356X_MEM_RESERVED_REGION;
  VirtualMemoryInfo[Index++].Name           = L"OP-TEE";

  // SCMI Mailbox
  VirtualMemoryTable[Index].PhysicalBase    = 0x10f000;
  VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
  VirtualMemoryTable[Index].Length          = 0x1000;
  VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_UNCACHED_UNBUFFERED;
  VirtualMemoryInfo[Index].Type             = RK356X_MEM_RESERVED_REGION;
  VirtualMemoryInfo[Index++].Name           = L"SCMI";
  
  // Firmware Volume
  VirtualMemoryTable[Index].PhysicalBase    = FixedPcdGet64 (PcdFdBaseAddress);
  VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
  VirtualMemoryTable[Index].Length          = FixedPcdGet32 (PcdFdSize);
  VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_WRITE_BACK;
  VirtualMemoryInfo[Index].Type             = RK356X_MEM_RESERVED_REGION;
  VirtualMemoryInfo[Index++].Name           = L"FD";

  // Flattened Device Tree
  VirtualMemoryTable[Index].PhysicalBase    = FixedPcdGet64 (PcdFdtBaseAddress);
  VirtualMemoryTable[Index].VirtualBase     = VirtualMemoryTable[Index].PhysicalBase;
  VirtualMemoryTable[Index].Length          = FixedPcdGet32 (PcdFdtSize);
  VirtualMemoryTable[Index].Attributes      = ARM_MEMORY_REGION_ATTRIBUTE_WRITE_BACK;
  VirtualMemoryInfo[Index].Type             = RK356X_MEM_RESERVED_REGION;
  VirtualMemoryInfo[Index++].Name           = L"Flattened Device Tree";

  // End of Table
  VirtualMemoryTable[Index].PhysicalBase    = 0;
  VirtualMemoryTable[Index].VirtualBase     = 0;
  VirtualMemoryTable[Index].Length          = 0;
  VirtualMemoryTable[Index++].Attributes    = (ARM_MEMORY_REGION_ATTRIBUTES)0;

  ASSERT(Index <= MAX_VIRTUAL_MEMORY_MAP_DESCRIPTORS);

  *VirtualMemoryMap = VirtualMemoryTable;
  VirtualMemoryInfoInitialized = TRUE;
}

/**
  Return additional memory info not populated by the above call.

  This call should follow the one to ArmPlatformGetVirtualMemoryMap ().

**/
VOID
Rk356xPlatformGetVirtualMemoryInfo (
  IN RK356X_MEMORY_REGION_INFO** MemoryInfo
  )
{
  ASSERT (VirtualMemoryInfo != NULL);

  if (!VirtualMemoryInfoInitialized) {
    DEBUG ((DEBUG_ERROR,
      "ArmPlatformGetVirtualMemoryMap must be called before Rk356xPlatformGetVirtualMemoryInfo.\n"));
    return;
  }

  *MemoryInfo = VirtualMemoryInfo;
}
