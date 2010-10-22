
#ifndef VBE_H
#define VBE_H

/* From VBE 3.0, http://www.vesa.org/vbe3.pdf */

typedef unsigned short dw;
typedef unsigned char db;
typedef unsigned int dd;

typedef struct vbe_modeinfoblock
{
  /* Mandatory information for all VBE revisions */
  dw mode_attributes;
  db win_a_attributes,win_b_attributes;
  dw win_granulatiry, win_size, win_a_segment, win_b_segment;
  dd win_func_ptr;
  dw bytes_per_scan_line;

  /* Mandatory information for VBE 1.2 and above */
  dw x_resolution, y_resolution;
  db x_char_size, y_char_size, number_of_planes, bits_per_pixel;
  db number_of_banks, memory_model, bank_size, number_of_image_pages;
  db reserved1;

  db red_mask_size ,red_field_position;
  db green_mask_size, green_field_position;
  db blue_mask_size, blue_field_position;
  db rsvd_mask_size, rsvd_field_position;
  db direct_color_mode_info;

  /* Mandatory information for VBE 2.0 and above */
  dd phys_base_ptr;
  dd reserved2;
  dw reserved3;

  /* Mandatory information for VBE 3.0 and above */
  dw lin_bytes_per_scan_line;
  db bnk_number_of_image_pages;
  db lin_number_of_image_pages;
  db lin_red_mask_size, lin_red_field_position;
  db lin_green_mask_size, lin_green_field_position;
  db lin_blue_mask_size, lin_blue_field_position;
  db lin_rsvd_mask_size, lin_rsvd_field_position;
  dd max_pixel_clock;
  db reserved4[189];

} __attribute((packed)) vbe_modeinfoblock_t;


typedef struct vbe_controlinfoblock {
   db vbesignature[4];   // VBE Signature
   dw vbeversion;        // VBE Version
   dd oemstringptr;      // Pointer to OEM String
   db capabilities[4];   // Capabilities of graphics cont.
   dd videomodeptr;      // Pointer to Video Mode List
   dw totalmemory;       // number of 64Kb memory blocks
   dw oemsoftwarerev;    // VBE implementation Software revision
   dd oemvendornameptr;  // Pointer to Vendor Name String
   dd oemproductnameptr; // Pointer to Product Name String
   dd oemproductrevptr;  // Pointer to Product Revision String
   db reserved[222];     // Reserved for VBE implementation scratch area
   db oemdata[256];      // Data Area for OEM Strings
} __attribute((packed)) vbe_controlinfoblock_t;

#endif
