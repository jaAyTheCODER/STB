#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>

EFI_STATUS
EFIAPI
UefiMain (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
    EFI_INPUT_KEY Key;
    UINTN Index;

    // Clear the screen using UEFI ConOut services
    SystemTable->ConOut->ClearScreen(SystemTable->ConOut);

    // Print header info
    Print(L"========================================\r\n");
    Print(L"             STB UEFI Firmware          \r\n");
    Print(L"========================================\r\n");
    Print(L"Status: Initialized successfully.\r\n\r\n");
    Print(L"Press any key to continue...\r\n");

    // Wait for a keypress event from the user
    gBS->WaitForEvent(1, &SystemTable->ConIn->WaitForKey, &Index);
    SystemTable->ConIn->ReadKeyStroke(SystemTable->ConIn, &Key);

    return EFI_SUCCESS;
}
