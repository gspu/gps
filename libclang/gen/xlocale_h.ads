pragma Ada_2012;
pragma Style_Checks (Off);

with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;

package xlocale_h is

   type uu_locale_data;
   type uu_locale_struct_uu_locales_array is array (0 .. 12) of access uu_locale_data;
   type uu_locale_struct_uu_names_array is array (0 .. 12) of Interfaces.C.Strings.chars_ptr;
   type uu_locale_struct is record
      uu_locales : uu_locale_struct_uu_locales_array;  -- /usr/include/xlocale.h:30
      uu_ctype_b : access unsigned_short;  -- /usr/include/xlocale.h:33
      uu_ctype_tolower : access int;  -- /usr/include/xlocale.h:34
      uu_ctype_toupper : access int;  -- /usr/include/xlocale.h:35
      uu_names : uu_locale_struct_uu_names_array;  -- /usr/include/xlocale.h:38
   end record
   with Convention => C_Pass_By_Copy;  -- /usr/include/xlocale.h:27

   type uu_locale_data is null record;   -- incomplete struct

   type uu_locale_t is access all uu_locale_struct;  -- /usr/include/xlocale.h:39

   subtype locale_t is uu_locale_t;  -- /usr/include/xlocale.h:42

end xlocale_h;
