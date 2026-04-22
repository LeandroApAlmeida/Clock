#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


/* 
===============================================================================

 Programa para a gravação de uma imagem de disco em um dispositivo de armazenamento.
 
===============================================================================
*/


// Define o tamanho do buffer para gravação (4MB).
#define BUFFER_SIZE (4 * 1024 * 1024)

// Define a largura da barra de progresso.
#define PROGRESS_BAR_WIDTH 50


/* 
===============================================================================

 Função para alinhar o tamanho de um buffer ao tamanho do setor do disco.
 
===============================================================================
*/

size_t align_buffer_size(size_t size, size_t align) {
	
	// Vamos usar como exemplo um setor de 512 bytes, e vamos alinhar um buffer
	// de 1500 bytes com este tamanho de setor.
	//
	//   > Passo 1: Calcular size + align - 1:
	//
	//     1500 + 512 - 1 = 2011
	//
	//   > Passo 2: Dividir pelo tamanho do setor (align):
	//
	//     2011 / 512 = 3 (parte inteira da divisão)
	//
	//   > Passo 3: Multiplicar pelo valor de align para obter o valor final, 
	//     alinhado:
	//
	//     3 * 512 = 1536
	//
	// O valor retornado pela chamada align_buffer_size(1500, 512) será 1536 bytes,
	// que é o próximo múltiplo de 512 maior que 1500. Com isso, temos um buffer 
	// que acomoda exatos 3 setores de disco.
	
    return ((size + align - 1) / align) * align;

}


/* 
===============================================================================

 Função para obter o tamanho do setor lógico do dispositivo de armazenamento.


 Documentação da API do Windows relacionada:

 https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ns-winioctl-storage_access_alignment_descriptor
 
 https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ns-winioctl-storage_property_query

 https://learn.microsoft.com/pt-br/windows/win32/api/ioapiset/nf-ioapiset-deviceiocontrol
 
 https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-ioctl_storage_query_property
 
===============================================================================
*/

DWORD get_sector_size(HANDLE disk_handle) {
	
	// Struct para descrever o alinhamento de acesso ao dispositivo. Ela contém o 
	// tamanho dos setores lógicos (em bytes), entre outras informações.
    STORAGE_ACCESS_ALIGNMENT_DESCRIPTOR descriptor;
    
	// Variável usada para armazenar o número de bytes lidos pela chamada à função
	// DeviceIoControl.
	DWORD bytes;
    
	// Struct do tipo STORAGE_PROPERTY_QUERY usada para configurar a consulta às 
	// propriedades do dispositivo. Ela é inicializada com {0} para garantir que 
	// todos os campos da struct comecem com valores zero.
	STORAGE_PROPERTY_QUERY query = {0};
    
	// Se query.PropertyId é configurado para StorageAccessAlignmentProperty, indica
	// que serão buscadas as informações sobre o alinhamento de acesso ao dispositivo, 
	// que incluem o tamanho do setor lógico.
	query.PropertyId = StorageAccessAlignmentProperty;
	
	// Se query.QueryType é configurado como PropertyStandardQuery, indica que a 
	// consulta será pelas propriedades do dispositivo de armazenamento.
    query.QueryType = PropertyStandardQuery;

	// DeviceIoControl é uma função usada para enviar um comando de controle para
	// o dispositivo de armazenamento. Estamos usando o comando de controle 
	// IOCTL_STORAGE_QUERY_PROPERTY, que solicita propriedades de armazenamento, 
	// como o alinhamento de acesso. É nesta struct que está o tamanho do setor
	// lógico que estamos procurando.
	//
	// Parâmetros:
	//
	//   >  disk_handle: Handle do disco.
	//
	//   > IOCTL_STORAGE_QUERY_PROPERTY: Código de operação que indica uma consulta 
	//     às propriedades do dispositivo.
	// 
	//   > &query: Ponteiro para a struct que contém as informações sobre a consulta.
	//
	//   > sizeof(query): Tamanho da query.
	//
	//   > &descriptor: Ponteiro para a struct STORAGE_ACCESS_ALIGNMENT_DESCRIPTOR, 
	//     onde as informações retornadas pela consulta serão gravadas.
	// 
	//   > sizeof(descriptor): Tamanho da struct descriptor.
	//
	//   > &bytes: Variável usada para armazenar o número de bytes lidos pela chamada
	//     à função DeviceIoControl.
	//
	//   > NULL: Não há um ponteiro para uma operação de sobrecarga ou outro controle
	//     adicional.
	//
	// A função DeviceIoControl retorna os dados da consulta em descriptor.
	
    if (DeviceIoControl(
            disk_handle,
            IOCTL_STORAGE_QUERY_PROPERTY,
            &query,
            sizeof(query),
            &descriptor,
            sizeof(descriptor),
            &bytes,
            NULL
		)) {
		
		// O campo descriptor.BytesPerLogicalSector contém o valor do tamanho do setor 
		// lógico do disco em bytes. Normalmente, este é o tamanho do setor físico 
		// do disco também.
		
        return descriptor.BytesPerLogicalSector;
		
    }

	// Caso não consiga obter o valor, retorna o valor padrão de 512 bytes, comum
	// à maioria dos dispositivos.
	
    return 512;
	
}


/* 
===============================================================================

 Função para detectar se o dispositivo de armazenamento é uma mídia removível.


 Documentação da API do Windows relacionada:

 https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ns-winioctl-storage_access_alignment_descriptor
 
 https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ns-winioctl-storage_property_query

 https://learn.microsoft.com/pt-br/windows/win32/api/ioapiset/nf-ioapiset-deviceiocontrol
 
 https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-ioctl_storage_query_property
 
===============================================================================
*/
int is_removable_device(int disk_number) {
	
    char path[32];
    
	sprintf(path, "\\\\.\\PhysicalDrive%d", disk_number);

    HANDLE disk_handle = CreateFileA(
		path, 
		GENERIC_READ, 
		FILE_SHARE_READ | FILE_SHARE_WRITE, 
		NULL, 
		OPEN_EXISTING, 
		0, 
		NULL
	);

    if (disk_handle == INVALID_HANDLE_VALUE) return 0;

    STORAGE_PROPERTY_QUERY query = {0};
	
    query.PropertyId = StorageDeviceProperty;
    query.QueryType = PropertyStandardQuery;

    BYTE buffer[1024];
	
    DWORD bytes;
    
	int removable = 0;

    if (DeviceIoControl(
            disk_handle,
            IOCTL_STORAGE_QUERY_PROPERTY,
            &query,
            sizeof(query),
            &buffer,
            sizeof(buffer),
            &bytes,
            NULL
		)) {
				
        STORAGE_DEVICE_DESCRIPTOR* descriptor = (STORAGE_DEVICE_DESCRIPTOR*)buffer;
		
        if (descriptor->RemovableMedia) removable = 1;
		
    }

    CloseHandle(disk_handle);
	
    return removable;
	
}


int get_disk_from_letter(char letter) {
	
    char path[16];
	
    sprintf(path, "\\\\.\\%c:", letter);

    HANDLE disk_handle = CreateFileA(
		path, 
		GENERIC_READ | GENERIC_WRITE, 
		FILE_SHARE_READ | FILE_SHARE_WRITE, 
		NULL, 
		OPEN_EXISTING, 
		0, 
		NULL
	);

    if (disk_handle == INVALID_HANDLE_VALUE) return -1;

    BYTE buffer[4096];
	
    DWORD bytes;

    if (!DeviceIoControl(
            disk_handle,
            IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,
            NULL,
            0,
            buffer,
            sizeof(buffer),
            &bytes,
            NULL
		)) {
			
        CloseHandle(disk_handle);
		
        return -1;
    
	}

    VOLUME_DISK_EXTENTS* extents = (VOLUME_DISK_EXTENTS*)buffer;
	
    int disk_number = extents->Extents[0].DiskNumber;
    
	CloseHandle(disk_handle);
    
	return disk_number;

}


int lock_and_dismount_volume(char letter) {
	
    char path[16];
    
	sprintf(path, "\\\\.\\%c:", letter);

    HANDLE disk_handle = CreateFileA(
		path, 
		GENERIC_READ | GENERIC_WRITE, 
		FILE_SHARE_READ | FILE_SHARE_WRITE, 
		NULL, 
		OPEN_EXISTING, 
		0, 
		NULL
	);

    if (disk_handle == INVALID_HANDLE_VALUE) return 0;

    DWORD bytes;

    if (!DeviceIoControl(
			disk_handle,
			FSCTL_LOCK_VOLUME,
			NULL, 
			0, 
			NULL, 
			0, 
			&bytes, 
			NULL
		)) {
			
        CloseHandle(disk_handle);
		
        return 0;
    
	}

    if (!DeviceIoControl(
			disk_handle, 
			FSCTL_DISMOUNT_VOLUME, 
			NULL, 
			0, 
			NULL, 
			0, 
			&bytes, 
			NULL
		)) {
			
        CloseHandle(disk_handle);
        
		return 0;
    
	}

    CloseHandle(disk_handle);
	
    return 1;
	
}


void update_progress_bar(LONGLONG written, LONGLONG total) {
	
    double percent = (double)written * 100.0 / (double)total;
    
	int position = (int)(percent / 100.0 * PROGRESS_BAR_WIDTH);

    printf("\r[");
    
	for (int i = 0; i < PROGRESS_BAR_WIDTH; i++) {
		
        if (i < position) printf("█");
		
        else printf(" ");
		
    }
    
	printf("] %6.2f%% (%lld/%lld bytes)", percent, written, total);
    
	fflush(stdout);

}


int eject_disk(int disk_number) {
    
	char path[32];
	
    sprintf(path, "\\\\.\\PhysicalDrive%d", disk_number);

    HANDLE disk_handle = CreateFileA(
		path,
		GENERIC_READ | GENERIC_WRITE, 
		FILE_SHARE_READ | FILE_SHARE_WRITE, 
		NULL, 
		OPEN_EXISTING, 
		0, 
		NULL
	);

    if (disk_handle == INVALID_HANDLE_VALUE) return 0;

    DWORD bytes;

    if (!DeviceIoControl(
            disk_handle,
            IOCTL_STORAGE_EJECT_MEDIA,
            NULL,
            0,
            NULL,
            0,
            &bytes,
            NULL
		)) {
			
        CloseHandle(disk_handle);
		
        return 0;
		
    }

    CloseHandle(disk_handle);
	
    return 1;
	
}


void print_header() {
	
	system("cls");
	
	char line[] = "==============================================================================================\n\n";

	printf("%s", line);
	
	int num_spaces = 25;
	
	printf("%*sGravador de Imagem de Disco, Versão 1.0\n\n", num_spaces, "");
	printf("%*sDesenvolvido por Leandro Ap. de Almeida\n\n", num_spaces, "");
	
	printf("%s", line);
	
}


int write_image_to_disk(const char *image_path) {
	
	print_header();
	
	printf("Discos removíveis encontrados:\n\n");

	int disk = -1;
	
    for (int d = 0; d < 16; d++) {

        if (is_removable_device(d)) {

            printf("  PhysicalDrive%d\n\n", d);

            disk = d;

            break;

        }

    }

    if (disk == -1) {

        printf("Nenhum disco removível encontrado.\n\n");

        return 1;

    }

    char letter;

    printf("Digite a letra da unidade (ex: E): ");

    scanf(" %c", &letter);

    int mapped_disk = get_disk_from_letter(letter);

    if (mapped_disk < 0) {

        printf("\n\nErro ao mapear disco.\n");

        return 1;

    }

    if (!is_removable_device(mapped_disk)) {

        printf("\n\nEsse disco não é removível.\n");

        return 1;

    }

    char disk_path[32];

    sprintf(disk_path, "\\\\.\\PhysicalDrive%d", mapped_disk);

    printf("\nDisco alvo: %s\n\n", disk_path);

    printf("ATENÇÃO: Isso apagará o disco inteiro! Continuar? (s/n): ");

    char c;

    scanf(" %c", &c);

    if (c != 's' && c != 'S') return 0;

    printf("\nDigite CONFIRMAR: ");

    char confirm[32];

    scanf("%s", confirm);
	
	print_header();

    if (strcmp(confirm, "CONFIRMAR") != 0) return 0;

    if (!lock_and_dismount_volume(letter)) {

        printf("\n\nFalha ao liberar volume.\n");

        return 1;

    }

    HANDLE image_handle = CreateFileA(
		image_path, 
		GENERIC_READ, 
		FILE_SHARE_READ, 
		NULL, 
		OPEN_EXISTING, 
		FILE_ATTRIBUTE_NORMAL, 
		NULL
	);
    
	HANDLE disk_handle = CreateFileA(
		disk_path, 
		GENERIC_READ | GENERIC_WRITE, 
		FILE_SHARE_READ | FILE_SHARE_WRITE, 
		NULL, 
		OPEN_EXISTING, 
		0, 
		NULL
	);

    if (image_handle == INVALID_HANDLE_VALUE || disk_handle == INVALID_HANDLE_VALUE) {
        
		printf(
			"Erro ao abrir arquivo ou disco (GetLastError=%lu)\n", 
			GetLastError()
		);
        
		return 1;
    
	}

    DWORD sector_size = get_sector_size(disk_handle);

    size_t buffer_size = align_buffer_size(BUFFER_SIZE, sector_size);

    char* buffer = (char*)_aligned_malloc(buffer_size, sector_size);

    if (!buffer) {

        printf("Falha de memória\n");

        return 1;

    }

    LARGE_INTEGER file_size;

    if (!GetFileSizeEx(image_handle, &file_size)) {

        printf("Falha ao obter tamanho do arquivo.\n");

        return 1;

    }

    DWORD read_bytes;

    LONGLONG total_written = 0;

    printf("Gravando imagem:\n\n");

    while (ReadFile(image_handle, buffer, buffer_size, &read_bytes, NULL) && read_bytes > 0) {

        if (read_bytes % sector_size != 0) {

            memset(buffer + read_bytes, 0, sector_size - (read_bytes % sector_size));

            read_bytes = (DWORD)align_buffer_size(read_bytes, sector_size);

        }

        DWORD written;

        if (!WriteFile(disk_handle, buffer, read_bytes, &written, NULL)) {

            printf("\nErro de escrita: %lu\n", GetLastError());

            break;

        }

        total_written += written;

        update_progress_bar(total_written, file_size.QuadPart);

    }

    printf("\n\nGravação concluída.\n");

    _aligned_free(buffer);
	
    CloseHandle(image_handle);

    CloseHandle(disk_handle);

    // Tentar ejetar o disco após a gravação
    if (eject_disk(mapped_disk)) {
		
        printf("\nO disco foi ejetado com sucesso.\n");

    } else {

        printf("\nFalha ao ejetar o disco.\n");

    }
	
	return 0;

}


int main(int argc, char* argv[]) {
    
	SetConsoleOutputCP(CP_UTF8);
	
    if (argc != 2) {
		
		printf("Uso: WriteDiskImage.exe <image_path>");
        
		return 1;
    
	}
	
	const char *image_path = argv[1];

    return write_image_to_disk(image_path);

}