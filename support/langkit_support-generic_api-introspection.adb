------------------------------------------------------------------------------
--                                                                          --
--                                 Langkit                                  --
--                                                                          --
--                     Copyright (C) 2014-2021, AdaCore                     --
--                                                                          --
-- Langkit is free software; you can redistribute it and/or modify it under --
-- terms of the  GNU General Public License  as published by the Free Soft- --
-- ware Foundation;  either version 3,  or (at your option)  any later ver- --
-- sion.   This software  is distributed in the hope that it will be useful --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY  or  FITNESS  FOR A PARTICULAR PURPOSE.                         --
--                                                                          --
-- As a special  exception  under  Section 7  of  GPL  version 3,  you are  --
-- granted additional  permissions described in the  GCC  Runtime  Library  --
-- Exception, version 3.1, as published by the Free Software Foundation.    --
--                                                                          --
-- You should have received a copy of the GNU General Public License and a  --
-- copy of the GCC Runtime Library Exception along with this program;  see  --
-- the files COPYING3 and COPYING.RUNTIME respectively.  If not, see        --
-- <http://www.gnu.org/licenses/>.                                          --
------------------------------------------------------------------------------

with Ada.Tags; use Ada.Tags;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;

with Langkit_Support.Errors;            use Langkit_Support.Errors;
with Langkit_Support.Internal.Analysis; use Langkit_Support.Internal.Analysis;
with Langkit_Support.Internal.Conversions;
use Langkit_Support.Internal.Conversions;
with Langkit_Support.Internal.Descriptor;
use Langkit_Support.Internal.Descriptor;
with Langkit_Support.Internal.Introspection;
use Langkit_Support.Internal.Introspection;

--  Even though we don't directly use entities from the Internal.Descriptor
--  package, we still need to import it to get visibility over the
--  Language_Descriptor type (and access its components).

pragma Unreferenced (Langkit_Support.Internal.Descriptor);

package body Langkit_Support.Generic_API.Introspection is

   use Langkit_Support.Errors.Introspection;

   --  Conversion helpers between the access types in the Generic API private
   --  part and in the internal API. We need to have different access types
   --  because of issues with the Ada privacy rules.

   function "+" is new Ada.Unchecked_Conversion
     (Langkit_Support.Internal.Introspection.Internal_Value_Access,
      Langkit_Support.Generic_API.Introspection.Internal_Value_Access);
   function "+" is new Ada.Unchecked_Conversion
     (Langkit_Support.Generic_API.Introspection.Internal_Value_Access,
      Langkit_Support.Internal.Introspection.Internal_Value_Access);

   procedure Check_Same_Language (Left, Right : Language_Id);
   --  Raise a ``Precondition_Failure`` exception if ``Left`` and ``Right`` are
   --  different.

   procedure Check_Type (T : Type_Ref);
   --  Raise a ``Precondition_Failure`` if ``T`` is ``No_Type_Ref``

   procedure Check_Type (Id : Language_Id; T : Type_Index);
   --  If ``T`` is not a valid type for the given language, raise a
   --  ``Precondition_Failure`` exception.

   procedure Check_Value (Value : Value_Ref);
   --  Raise a ``Precondition_Failure`` exception if ``Value`` is null

   procedure Check_Value_Type (Value : Value_Ref; T : Type_Index);
   --  Raise a ``Precondition_Failure`` exception if ``Value`` does not match
   --  ``T``.

   procedure Check_Enum_Type (Enum : Type_Ref);
   --  If ``Enum`` is not a valid enum type, raise a ``Precondition_Failure``
   --  exception.

   procedure Check_Enum_Value (Value : Enum_Value_Ref);
   --  If ``Value`` is not a valid enum value, raise a ``Precondition_Failure``
   --  exception.

   procedure Check_Enum_Value (Enum : Type_Ref; Index : Enum_Value_Index);
   --  If ``Enum`` is not a valid enum type or if ``Index`` is not a valid
   --  value for that type, raise a ``Precondition_Failure`` exception.

   procedure Check_Array_Type (T : Type_Ref);
   --  If ``T`` is not a valid array type for the given language, raise a
   --  ``Precondition_Failure`` exception.

   procedure Check_Base_Struct_Type (T : Type_Ref);
   --  If ``T`` is not a valid base struct type for the given language, raise a
   --  ``Precondition_Failure`` exception.

   procedure Check_Struct_Type (T : Type_Ref);
   --  If ``T`` is not a valid struct type for the given language, raise a
   --  ``Precondition_Failure`` exception.

   procedure Check_Node_Type (Node : Type_Ref);
   --  If ``Node`` is not a valid node type for the given language, raise a
   --  ``Precondition_Failure`` exception.

   procedure Check_Struct_Member (Member : Struct_Member_Ref);
   --  Raise a ``Precondition_Failure`` if ``Member`` is
   --  ``No_Struct_Member_Ref``.

   procedure Check_Struct_Member
     (Id : Language_Id; Member : Struct_Member_Index);
   --  If ``Member`` is not a valid struct member for the given language, raise
   --  a ``Precondition_Failure`` exception.

   procedure Check_Struct_Member_Argument
     (Member : Struct_Member_Ref; Argument : Argument_Index);
   --  If ``Member`` is not a valid struct member for the given language or if
   --  ``Argument`` is not a valid argument for that member, raise a
   --  ``Precondition_Failure`` exception.

   function Create_Value
     (Id : Language_Id; Value : Internal_Value_Access) return Value_Ref;
   --  Initialize ``Value`` with ``Id``, set it a ref-count of 1 and return it
   --  wrapped as a ``Value_Ref``.

   -------------------------
   -- Check_Same_Language --
   -------------------------

   procedure Check_Same_Language (Left, Right : Language_Id) is
   begin
      if Left /= Right then
         raise Precondition_Failure with "inconsistent languages";
      end if;
   end Check_Same_Language;

   ----------------
   -- Check_Type --
   ----------------

   procedure Check_Type (T : Type_Ref) is
   begin
      if T.Id = null then
         raise Precondition_Failure with "null type reference";
      end if;
   end Check_Type;

   ----------------
   -- Check_Type --
   ----------------

   procedure Check_Type (Id : Language_Id; T : Type_Index) is
   begin
      if T > Last_Type (Id) then
         raise Precondition_Failure with "invalid type index";
      end if;
   end Check_Type;

   ----------------
   -- Debug_Name --
   ----------------

   function Debug_Name (T : Type_Ref) return String is
   begin
      if T = No_Type_Ref then
         return "<No_Type_Ref>";
      else
         return T.Id.Types (T.Index).Debug_Name.all;
      end if;
   end Debug_Name;

   ------------------
   -- Language_For --
   ------------------

   function Language_For (T : Type_Ref) return Language_Id is
   begin
      Check_Type (T);
      return T.Id;
   end Language_For;

   --------------
   -- To_Index --
   --------------

   function To_Index (T : Type_Ref) return Type_Index is
   begin
      Check_Type (T);
      return T.Index;
   end To_Index;

   ----------------
   -- From_Index --
   ----------------

   function From_Index (Id : Language_Id; T : Type_Index) return Type_Ref is
   begin
      Check_Type (Id, T);
      return (Id, T);
   end From_Index;

   ---------------
   -- Last_Type --
   ---------------

   function Last_Type (Id : Language_Id) return Type_Index is
   begin
      return Id.Types.all'Last;
   end Last_Type;

   -----------------
   -- Check_Value --
   -----------------

   procedure Check_Value (Value : Value_Ref) is
   begin
      if Value.Value = null then
         raise Precondition_Failure with "null value reference";
      end if;
   end Check_Value;

   ----------------------
   -- Check_Value_Type --
   ----------------------

   procedure Check_Value_Type (Value : Value_Ref; T : Type_Index) is
   begin
      if not Value.Value.Type_Matches (T) then
         raise Precondition_Failure with "unexpected value type";
      end if;
   end Check_Value_Type;

   ---------
   -- "=" --
   ---------

   function "=" (Left, Right : Value_Ref) return Boolean is
   begin
      --  Easy case: Left and Right are not only structurally equivalent, but
      --  have shallow equality.

      if Left.Value = Right.Value then
         return True;

      --  We cannot dereference both values without preliminary checks because
      --  it is legal to get null values. Also make sure we have values of the
      --  same type (the comparison would raise a Constraint_Error otherwise).

      elsif Left.Value = null
            or else Right.Value = null
            or else Left.Value.all'Tag /= Right.Value.all'Tag
      then
         return False;

      else
         return Left.Value.all = Right.Value.all;
      end if;
   end "=";

   ------------------
   -- Language_For --
   ------------------

   function Language_For (Value : Value_Ref) return Language_Id is
   begin
      Check_Value (Value);
      return Value.Value.Id;
   end Language_For;

   -------------
   -- Type_Of --
   -------------

   function Type_Of (Value : Value_Ref) return Type_Ref is
   begin
      Check_Value (Value);
      return From_Index (Value.Value.Id, Value.Value.Type_Of);
   end Type_Of;

   ------------------
   -- Type_Matches --
   ------------------

   function Type_Matches (Value : Value_Ref; T : Type_Ref) return Boolean is
   begin
      Check_Value (Value);
      Check_Type (T);
      if Value.Value.Id /= T.Id then
         raise Precondition_Failure with "inconsistent language";
      end if;
      return Value.Value.Type_Matches (T.Index);
   end Type_Matches;

   -----------
   -- Image --
   -----------

   function Image (Value : Value_Ref) return String is
   begin
      if Value.Value = null then
         return "<No_Value_Ref>";
      end if;
      return Value.Value.Image;
   end Image;

   ------------------
   -- Create_Value --
   ------------------

   function Create_Value
     (Id : Language_Id; Value : Internal_Value_Access) return Value_Ref is
   begin
      return Result : Value_Ref do
         Value.Id := Id;
         Value.Ref_Count := 1;
         Result.Value := Value;
      end return;
   end Create_Value;

   -----------------
   -- Create_Unit --
   -----------------

   function Create_Unit (Id : Language_Id; Value : Lk_Unit) return Value_Ref is
      Result : Internal_Acc_Analysis_Unit;
   begin
      if Value /= No_Lk_Unit then
         Check_Same_Language (Id, Value.Language_For);
      end if;
      Result := new Internal_Rec_Analysis_Unit;
      Result.Value := Value;
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Unit;

   -------------
   -- As_Unit --
   -------------
   function As_Unit (Value : Value_Ref) return Lk_Unit is
      Id : Language_Id;
      V  : Internal_Acc_Analysis_Unit;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.Analysis_Unit);
      V := Internal_Acc_Analysis_Unit (Value.Value);
      return V.Value;
   end As_Unit;

   --------------------
   -- Create_Big_Int --
   --------------------

   function Create_Big_Int
     (Id : Language_Id; Value : Big_Integer) return Value_Ref
   is
      Result : constant Internal_Acc_Big_Int := new Internal_Rec_Big_Int;
   begin
      Result.Value.Set (Value);
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Big_Int;

   ----------------
   -- As_Big_Int --
   ----------------

   function As_Big_Int (Value : Value_Ref) return Big_Integer is
      Id : Language_Id;
      V  : Internal_Acc_Big_Int;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.Big_Int);
      V := Internal_Acc_Big_Int (Value.Value);
      return Result : Big_Integer do
         Result.Set (V.Value);
      end return;
   end As_Big_Int;

   -----------------
   -- Create_Bool --
   -----------------

   function Create_Bool (Id : Language_Id; Value : Boolean) return Value_Ref is
      Result : constant Internal_Acc_Bool := new Internal_Rec_Bool;
   begin
      Result.Value := Value;
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Bool;

   -------------
   -- As_Bool --
   -------------

   function As_Bool (Value : Value_Ref) return Boolean is
      Id : Language_Id;
      V  : Internal_Acc_Bool;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.Bool);
      V := Internal_Acc_Bool (Value.Value);
      return V.Value;
   end As_Bool;

   -----------------
   -- Create_Char --
   -----------------

   function Create_Char
     (Id : Language_Id; Value : Character_Type) return Value_Ref
   is
      Result : constant Internal_Acc_Character := new Internal_Rec_Character;
   begin
      Result.Value := Value;
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Char;

   -------------
   -- As_Char --
   -------------

   function As_Char (Value : Value_Ref) return Character_Type is
      Id : Language_Id;
      V  : Internal_Acc_Character;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.Char);
      V := Internal_Acc_Character (Value.Value);
      return V.Value;
   end As_Char;

   ----------------
   -- Create_Int --
   ----------------

   function Create_Int (Id : Language_Id; Value : Integer) return Value_Ref is
      Result : constant Internal_Acc_Int := new Internal_Rec_Int;
   begin
      Result.Value := Value;
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Int;

   ------------
   -- As_Int --
   ------------

   function As_Int (Value : Value_Ref) return Integer is
      Id : Language_Id;
      V  : Internal_Acc_Int;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.Int);
      V := Internal_Acc_Int (Value.Value);
      return V.Value;
   end As_Int;

   ----------------------------------
   -- Create_Source_Location_Range --
   ----------------------------------

   function Create_Source_Location_Range
     (Id : Language_Id; Value : Source_Location_Range) return Value_Ref
   is
      Result : constant Internal_Acc_Source_Location_Range :=
        new Internal_Rec_Source_Location_Range;
   begin
      Result.Value := Value;
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Source_Location_Range;

   ------------------------------
   -- As_Source_Location_Range --
   ------------------------------

   function As_Source_Location_Range
     (Value : Value_Ref) return Source_Location_Range
   is
      Id : Language_Id;
      V  : Internal_Acc_Source_Location_Range;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.Source_Location_Range);
      V := Internal_Acc_Source_Location_Range (Value.Value);
      return V.Value;
   end As_Source_Location_Range;

   -------------------
   -- Create_String --
   -------------------

   function Create_String
     (Id : Language_Id; Value : Text_Type) return Value_Ref
   is
      Result : constant Internal_Acc_String := new Internal_Rec_String;
   begin
      Result.Value := To_Unbounded_Text (Value);
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_String;

   ---------------
   -- As_String --
   ---------------

   function As_String (Value : Value_Ref) return Text_Type is
      Id : Language_Id;
      V  : Internal_Acc_String;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.String);
      V := Internal_Acc_String (Value.Value);
      return To_Text (V.Value);
   end As_String;

   ------------------
   -- Create_Token --
   ------------------

   function Create_Token (Id : Language_Id; Value : Lk_Token) return Value_Ref
   is
      Result : Internal_Acc_Token;
   begin
      if Value /= No_Lk_Token then
         Check_Same_Language (Id, Value.Language_For);
      end if;
      Result := new Internal_Rec_Token;
      Result.Value := Value;
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Token;

   --------------
   -- As_Token --
   --------------

   function As_Token (Value : Value_Ref) return Lk_Token is
      Id : Language_Id;
      V  : Internal_Acc_Token;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.Token);
      V := Internal_Acc_Token (Value.Value);
      return V.Value;
   end As_Token;

   -------------------
   -- Create_Symbol --
   -------------------

   function Create_Symbol
     (Id : Language_Id; Value : Text_Type) return Value_Ref
   is
      Result : constant Internal_Acc_Symbol := new Internal_Rec_Symbol;
   begin
      Result.Value := To_Unbounded_Text (Value);
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Symbol;

   ---------------
   -- As_Symbol --
   ---------------

   function As_Symbol (Value : Value_Ref) return Text_Type is
      Id : Language_Id;
      V  : Internal_Acc_Symbol;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.Builtin_Types.Symbol);
      V := Internal_Acc_Symbol (Value.Value);
      return To_Text (V.Value);
   end As_Symbol;

   -----------------
   -- Create_Node --
   -----------------

   function Create_Node (Id : Language_Id; Value : Lk_Node) return Value_Ref is
      Result : Internal_Acc_Node;
   begin
      if Value /= No_Lk_Node then
         Check_Same_Language (Id, Value.Language_For);
      end if;
      Result := new Internal_Rec_Node;
      Result.Value := Value;
      return Create_Value (Id, Internal_Value_Access (Result));
   end Create_Node;

   -------------
   -- As_Node --
   -------------

   function As_Node (Value : Value_Ref) return Lk_Node is
      Id : Language_Id;
      V  : Internal_Acc_Node;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      Check_Value_Type (Value, Id.First_Node);
      V := Internal_Acc_Node (Value.Value);
      return V.Value;
   end As_Node;

   -------------
   -- Type_Of --
   -------------

   function Type_Of (Node : Lk_Node) return Type_Ref is
   begin
      if Node = No_Lk_Node then
         raise Precondition_Failure with "null node";
      end if;

      declare
         Id     : constant Language_Id := Language_For (Node);
         E      : constant Internal.Analysis.Internal_Entity :=
           Unwrap_Node (Node);
         Result : constant Type_Index := Id.Node_Kind (E.Node);
      begin
         return From_Index (Id, Result);
      end;
   end Type_Of;

   ------------
   -- Adjust --
   ------------

   overriding procedure Adjust (Self : in out Value_Ref) is
   begin
      if Self.Value /= null then
         Self.Value.Ref_Count := Self.Value.Ref_Count + 1;
      end if;
   end Adjust;

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out Value_Ref) is
      procedure Free is new Ada.Unchecked_Deallocation
        (Internal_Value'Class, Internal_Value_Access);
   begin
      if Self.Value /= null then
         if Self.Value.Ref_Count = 1 then
            Self.Value.Destroy;
            Free (Self.Value);
         else
            Self.Value.Ref_Count := Self.Value.Ref_Count - 1;
            Self.Value := null;
         end if;
      end if;
   end Finalize;

   ------------------
   -- Is_Enum_Type --
   ------------------

   function Is_Enum_Type (T : Type_Ref) return Boolean is
   begin
      Check_Type (T);
      return T.Index in T.Id.Enum_Types.all'Range;
   end Is_Enum_Type;

   ---------------------
   -- Check_Enum_Type --
   ---------------------

   procedure Check_Enum_Type (Enum : Type_Ref) is
   begin
      if not Is_Enum_Type (Enum) then
         raise Precondition_Failure with "invalid enum type";
      end if;
   end Check_Enum_Type;

   ----------------------
   -- Check_Enum_Value --
   ----------------------

   procedure Check_Enum_Value (Value : Enum_Value_Ref) is
   begin
      if Value.Enum.Id = null then
         raise Precondition_Failure with "null enum value reference";
      end if;
   end Check_Enum_Value;

   ----------------------
   -- Check_Enum_Value --
   ----------------------

   procedure Check_Enum_Value (Enum : Type_Ref; Index : Enum_Value_Index) is
   begin
      Check_Enum_Type (Enum);
      if Index > Enum.Id.Enum_Types.all (Enum.Index).Last_Value then
         raise Precondition_Failure with "invalid enum value index";
      end if;
   end Check_Enum_Value;

   --------------------
   -- Enum_Type_Name --
   --------------------

   function Enum_Type_Name (Enum : Type_Ref) return Name_Type is
   begin
      Check_Enum_Type (Enum);
      return Create_Name (Enum.Id.Enum_Types.all (Enum.Index).Name.all);
   end Enum_Type_Name;

   --------------
   -- Enum_For --
   --------------

   function Enum_For (Value : Enum_Value_Ref) return Type_Ref is
   begin
      return Value.Enum;
   end Enum_For;

   ------------------------
   -- Enum_Default_Value --
   ------------------------

   function Enum_Default_Value (Enum : Type_Ref) return Enum_Value_Ref is
      Index : Any_Enum_Value_Index;
   begin
      Check_Enum_Type (Enum);
      Index := Enum.Id.Enum_Types.all (Enum.Index).Default_Value;
      return (if Index = No_Enum_Value_Index
              then No_Enum_Value_Ref
              else From_Index (Enum, Index));
   end Enum_Default_Value;

   ---------------------
   -- Enum_Value_Name --
   ---------------------

   function Enum_Value_Name (Value : Enum_Value_Ref) return Name_Type is
   begin
      Check_Enum_Value (Value);

      declare
         Enum : Type_Ref renames Value.Enum;
         Desc : Enum_Type_Descriptor renames
           Enum.Id.Enum_Types.all (Enum.Index).all;
      begin
         return Create_Name (Desc.Value_Names (Value.Index).all);
      end;
   end Enum_Value_Name;

   --------------
   -- To_Index --
   --------------

   function To_Index (Value : Enum_Value_Ref) return Enum_Value_Index is
   begin
      Check_Enum_Value (Value);
      return Value.Index;
   end To_Index;

   ----------------
   -- From_Index --
   ----------------

   function From_Index
     (Enum : Type_Ref; Value : Enum_Value_Index) return Enum_Value_Ref is
   begin
      Check_Enum_Value (Enum, Value);
      return (Enum, Value);
   end From_Index;

   ---------------------
   -- Enum_Last_Value --
   ---------------------

   function Enum_Last_Value (Enum : Type_Ref) return Enum_Value_Index is
   begin
      Check_Enum_Type (Enum);
      return Enum.Id.Enum_Types.all (Enum.Index).Last_Value;
   end Enum_Last_Value;

   -----------------
   -- Create_Enum --
   -----------------

   function Create_Enum (Value : Enum_Value_Ref) return Value_Ref is
      Id : Language_Id;
   begin
      Check_Enum_Value (Value);
      Id := Value.Enum.Id;
      return Create_Value
        (Id, +Id.Create_Enum (Value.Enum.Index, Value.Index));
   end Create_Enum;

   -------------
   -- As_Enum --
   -------------

   function As_Enum (Value : Value_Ref) return Enum_Value_Ref is
      Id : Language_Id;
      T  : Type_Ref;
      V  : Base_Internal_Enum_Value_Access;
   begin
      Check_Value (Value);
      Id := Value.Value.Id;
      T := From_Index (Id, Value.Value.Type_Of);
      if not Is_Enum_Type (T) then
         raise Precondition_Failure with "non-enum value";
      end if;
      V := Base_Internal_Enum_Value_Access (Value.Value);
      return From_Index (T, V.Value_Index);
   end As_Enum;

   -------------------
   -- Is_Array_Type --
   -------------------

   function Is_Array_Type (T : Type_Ref) return Boolean is
   begin
      Check_Type (T);
      return T.Index in T.Id.Array_Types.all'Range;
   end Is_Array_Type;

   ----------------------
   -- Check_Array_Type --
   ----------------------

   procedure Check_Array_Type (T : Type_Ref) is
   begin
      if not Is_Array_Type (T) then
         raise Precondition_Failure with "invalid array type";
      end if;
   end Check_Array_Type;

   ------------------------
   -- Array_Element_Type --
   ------------------------

   function Array_Element_Type (T : Type_Ref) return Type_Ref is
   begin
      Check_Array_Type (T);
      return From_Index (T.Id, T.Id.Array_Types.all (T.Index).Element_Type);
   end Array_Element_Type;

   ------------------
   -- Create_Array --
   ------------------

   function Create_Array
     (T : Type_Ref; Values : Value_Ref_Array) return Value_Ref
   is
      ET              : constant Type_Index :=
        To_Index (Array_Element_Type (T));
      Internal_Values : Internal_Value_Array (Values'Range);
   begin
      Check_Array_Type (T);

      for I in Values'Range loop
         declare
            V : constant Value_Ref := Values (I);
         begin
            Check_Value (V);
            Check_Same_Language (T.Id, V.Language_For);
            Check_Value_Type (V, ET);
            Internal_Values (I) := +V.Value;
         end;
      end loop;

      return Create_Value
        (T.Id, +T.Id.Create_Array (To_Index (T), Internal_Values));
   end Create_Array;

   --------------
   -- As_Array --
   --------------

   function As_Array (Value : Value_Ref) return Value_Ref_Array is
   begin
      return Result : Value_Ref_Array (1 .. Array_Length (Value)) do
         for I in Result'Range loop
            Result (I) := Array_Item (Value, I);
         end loop;
      end return;
   end As_Array;

   ------------------
   -- Array_Length --
   ------------------

   function Array_Length (Value : Value_Ref) return Natural is
      T : Type_Ref;
      V : Base_Internal_Array_Value_Access;
   begin
      Check_Value (Value);
      T := Value.Type_Of;
      if not Is_Array_Type (T) then
         raise Precondition_Failure with "non-array value";
      end if;
      V := Base_Internal_Array_Value_Access (Value.Value);
      return V.Array_Length;
   end Array_Length;

   ----------------
   -- Array_Item --
   ----------------

   function Array_Item (Value : Value_Ref; Index : Positive) return Value_Ref
   is
      V : Base_Internal_Array_Value_Access;
   begin
      if Index > Array_Length (Value) then
         raise Precondition_Failure with "out-of-bounds array index";
      end if;
      V := Base_Internal_Array_Value_Access (Value.Value);
      return Create_Value (V.Id, +V.Array_Item (Index));
   end Array_Item;

   -------------------------
   -- Is_Base_Struct_Type --
   -------------------------

   function Is_Base_Struct_Type (T : Type_Ref) return Boolean is
   begin
      return Is_Struct_Type (T) or else Is_Node_Type (T);
   end Is_Base_Struct_Type;

   ----------------------------
   -- Check_Base_Struct_Type --
   ----------------------------

   procedure Check_Base_Struct_Type (T : Type_Ref) is
   begin
      if not Is_Base_Struct_Type (T) then
         raise Precondition_Failure with "invalid base struct type";
      end if;
   end Check_Base_Struct_Type;

   ---------------------------
   -- Base_Struct_Type_Name --
   ---------------------------

   function Base_Struct_Type_Name (T : Type_Ref) return Name_Type is
   begin
      Check_Base_Struct_Type (T);
      return Create_Name (T.Id.Struct_Types.all (T.Index).Name.all);
   end Base_Struct_Type_Name;

   --------------------
   -- Is_Struct_Type --
   --------------------

   function Is_Struct_Type (T : Type_Ref) return Boolean is
   begin
      Check_Type (T);
      return T.Index in T.Id.Struct_Types.all'First .. T.Id.First_Node - 1;
   end Is_Struct_Type;

   -----------------------
   -- Check_Struct_Type --
   -----------------------

   procedure Check_Struct_Type (T : Type_Ref) is
   begin
      if not Is_Struct_Type (T) then
         raise Precondition_Failure with "invalid struct type";
      end if;
   end Check_Struct_Type;

   ----------------------
   -- Struct_Type_Name --
   ----------------------

   function Struct_Type_Name (Struct : Type_Ref) return Name_Type is
   begin
      Check_Struct_Type (Struct);
      return Create_Name (Struct.Id.Struct_Types.all (Struct.Index).Name.all);
   end Struct_Type_Name;

   -------------------
   -- Create_Struct --
   -------------------

   function Create_Struct
     (T : Type_Ref; Values : Value_Ref_Array) return Value_Ref
   is
      Members         : constant Struct_Member_Ref_Array :=
        Introspection.Members (T);
      Internal_Values : Internal_Value_Array (Values'Range);
   begin
      Check_Struct_Type (T);

      --  Check that Values contain valid values for T's language

      for V of Values loop
         if V = No_Value_Ref then
            raise Precondition_Failure with "invalid null value";
         elsif V.Value.Id /= T.Id then
            raise Precondition_Failure with "inconsistent language";
         end if;
      end loop;

      --  Check that Values match T's members

      if Values'Length /= Members'Length then
         raise Precondition_Failure with
           Debug_Name (T) & " has" & Natural'Image (Members'Length)
           & " members but got" & Natural'Image (Values'Length) & " value(s)";
      end if;

      for I in 0 .. Members'Length - 1 loop
         declare
            V : Value_Ref renames Values (Values'First + I);
            T : constant Type_Ref := Member_Type (Members (Members'First + I));
         begin
            if not Type_Matches (V, T) then
               raise Precondition_Failure with "member type mismatch";
            end if;
         end;
      end loop;

      --  Unpack values for members and actually build the struct

      for I in Values'Range loop
         Internal_Values (I) := +Values (I).Value;
      end loop;
      return Create_Value
        (T.Id, +T.Id.Create_Struct (To_Index (T), Internal_Values));
   end Create_Struct;

   ------------------
   -- Is_Node_Type --
   ------------------

   function Is_Node_Type (T : Type_Ref) return Boolean is
   begin
      Check_Type (T);
      return T.Index in T.Id.First_Node .. T.Id.Struct_Types.all'Last;
   end Is_Node_Type;

   ---------------------
   -- Check_Node_Type --
   ---------------------

   procedure Check_Node_Type (Node : Type_Ref) is
   begin
      if not Is_Node_Type (Node) then
         raise Precondition_Failure with "invalid node type";
      end if;
   end Check_Node_Type;

   --------------------
   -- Root_Node_Type --
   --------------------

   function Root_Node_Type (Id : Language_Id) return Type_Ref is
   begin
      return From_Index (Id, Id.First_Node);
   end Root_Node_Type;

   --------------------
   -- Node_Type_Name --
   --------------------

   function Node_Type_Name (Node : Type_Ref) return Name_Type is
   begin
      Check_Node_Type (Node);
      return Create_Name (Node.Id.Struct_Types.all (Node.Index).Name.all);
   end Node_Type_Name;

   -----------------
   -- Is_Abstract --
   -----------------

   function Is_Abstract (Node : Type_Ref) return Boolean is
   begin
      Check_Node_Type (Node);
      return Node.Id.Struct_Types.all (Node.Index).Is_Abstract;
   end Is_Abstract;

   ---------------
   -- Base_Type --
   ---------------

   function Base_Type (Node : Type_Ref) return Type_Ref is
   begin
      Check_Node_Type (Node);
      if Node = Root_Node_Type (Node.Id) then
         raise Bad_Type_Error with "trying to get base type of root node";
      end if;
      return From_Index
        (Node.Id, Node.Id.Struct_Types.all (Node.Index).Base_Type);
   end Base_Type;

   -------------------
   -- Derived_Types --
   -------------------

   function Derived_Types (Node : Type_Ref) return Type_Ref_Array is
   begin
      Check_Node_Type (Node);
      declare
         Derivations : Type_Index_Array renames
           Node.Id.Struct_Types.all (Node.Index).Derivations;
      begin
         return Result : Type_Ref_Array (Derivations'Range) do
            for I in Result'Range loop
               Result (I) := From_Index (Node.Id, Derivations (I));
            end loop;
         end return;
      end;
   end Derived_Types;

   -----------------------
   -- Last_Derived_Type --
   -----------------------

   function Last_Derived_Type (Node : Type_Ref) return Type_Index is
      --  Look for the last derivations's derivation, recursively

      Result : Any_Type_Index := Node.Index;
   begin
      Check_Node_Type (Node);

      loop
         declare
            Desc : Struct_Type_Descriptor renames
              Node.Id.Struct_Types.all (Result).all;
         begin
            exit when Desc.Derivations'Length = 0;
            Result := Desc.Derivations (Desc.Derivations'Last);
         end;
      end loop;
      return Result;
   end Last_Derived_Type;

   ---------------------
   -- Is_Derived_From --
   ---------------------

   function Is_Derived_From (Node, Parent : Type_Ref) return Boolean is
   begin
      Check_Node_Type (Node);
      Check_Node_Type (Parent);
      if Node.Id /= Parent.Id then
         raise Precondition_Failure with
           "Node and Parent belong to different languages";
      end if;

      declare
         Id           : constant Language_Id := Node.Id;
         Struct_Types : Struct_Type_Descriptor_Array renames
           Id.Struct_Types.all;
         Cursor       : Any_Type_Index := Node.Index;
      begin
         while Cursor /= No_Type_Index loop
            if Cursor = Parent.Index then
               return True;
            end if;

            Cursor := Struct_Types (Cursor).Base_Type;
         end loop;
         return False;
      end;
   end Is_Derived_From;

   -------------------------
   -- Check_Struct_Member --
   -------------------------

   procedure Check_Struct_Member (Member : Struct_Member_Ref) is
   begin
      if Member.Id = null then
         raise Precondition_Failure with "null struct member reference";
      end if;
   end Check_Struct_Member;

   -------------------------
   -- Check_Struct_Member --
   -------------------------

   procedure Check_Struct_Member
     (Id : Language_Id; Member : Struct_Member_Index) is
   begin
      if Member not in Id.Struct_Members.all'Range then
         raise Precondition_Failure with "invalid struct member index";
      end if;
   end Check_Struct_Member;

   ----------------------------------
   -- Check_Struct_Member_Argument --
   ----------------------------------

   procedure Check_Struct_Member_Argument
     (Member : Struct_Member_Ref; Argument : Argument_Index) is
   begin
      Check_Struct_Member (Member);
      declare
         Desc : Struct_Member_Descriptor renames
           Member.Id.Struct_Members.all (Member.Index).all;
      begin
         if Argument not in Desc.Arguments'Range then
            raise Precondition_Failure with "invalid struct member argument";
         end if;
      end;
   end Check_Struct_Member_Argument;

   ----------------
   -- Debug_Name --
   ----------------

   function Debug_Name (Member : Struct_Member_Ref) return String is
   begin
      return Debug_Name (Owner (Member)) & "."
             & Image (Format_Name (Member_Name (Member), Lower));
   end Debug_Name;

   -----------
   -- Owner --
   -----------

   function Owner (Member : Struct_Member_Ref) return Type_Ref is
   begin
      Check_Struct_Member (Member);
      return From_Index
        (Member.Id, Member.Id.Struct_Members.all (Member.Index).Owner);
   end Owner;

   -----------------
   -- Is_Property --
   -----------------

   function Is_Property (Member : Struct_Member_Ref) return Boolean is
   begin
      Check_Struct_Member (Member);
      return Member.Index >= Member.Id.First_Property;
   end Is_Property;

   -------------
   -- Members --
   -------------

   function Members (Struct : Type_Ref) return Struct_Member_Ref_Array is
      Id : Language_Id;

      Current_Struct : Any_Type_Index := Struct.Index;
      --  Cursor to "climb up" the derivation hierarchy for ``Struct``: we want
      --  ``Struct``'s own fields, but also the inheritted ones.

      Next : Natural;
      --  Index in ``Result`` (see below) for the next member to add
   begin
      Check_Base_Struct_Type (Struct);
      Id := Struct.Id;
      return Result : Struct_Member_Ref_Array
        (1 .. Id.Struct_Types.all (Struct.Index).Inherited_Members)
      do
         --  Go through the derivation chain and collect field in ``Result``.
         --  Add them in reverse order so that in the end, inherited members
         --  are first, and are in declaration order.

         Next := Result'Last;
         while Current_Struct /= No_Type_Index loop
            for M of reverse Id.Struct_Types.all (Current_Struct).Members loop
               Result (Next) := From_Index (Id, M);
               Next := Next - 1;
            end loop;
            Current_Struct := Id.Struct_Types.all (Current_Struct).Base_Type;
         end loop;
      end return;
   end Members;

   -----------------
   -- Member_Name --
   -----------------

   function Member_Name (Member : Struct_Member_Ref) return Name_Type is
   begin
      Check_Struct_Member (Member);
      return Create_Name
        (Member.Id.Struct_Members.all (Member.Index).Name.all);
   end Member_Name;

   -----------------
   -- Member_Type --
   -----------------

   function Member_Type (Member : Struct_Member_Ref) return Type_Ref is
   begin
      Check_Struct_Member (Member);
      return From_Index
        (Member.Id, Member.Id.Struct_Members.all (Member.Index).Member_Type);
   end Member_Type;

   --------------
   -- To_Index --
   --------------

   function To_Index (Member : Struct_Member_Ref) return Struct_Member_Index is
   begin
      Check_Struct_Member (Member);
      return Member.Index;
   end To_Index;

   ----------------
   -- From_Index --
   ----------------

   function From_Index
     (Id : Language_Id; Member : Struct_Member_Index) return Struct_Member_Ref
   is
   begin
      Check_Struct_Member (Id, Member);
      return (Id, Member);
   end From_Index;

   ------------------------
   -- Last_Struct_Member --
   ------------------------

   function Last_Struct_Member (Id : Language_Id) return Struct_Member_Index is
   begin
      return Id.Struct_Members.all'Last;
   end Last_Struct_Member;

   --------------------------
   -- Member_Argument_Type --
   --------------------------

   function Member_Argument_Type
     (Member : Struct_Member_Ref; Argument : Argument_Index) return Type_Ref
   is
      Id : Language_Id;
   begin
      Check_Struct_Member (Member);
      Check_Struct_Member_Argument (Member, Argument);
      Id := Member.Id;
      return From_Index
        (Id,
         Id.Struct_Members.all
           (Member.Index).Arguments (Argument).Argument_Type);
   end Member_Argument_Type;

   --------------------------
   -- Member_Argument_Name --
   --------------------------

   function Member_Argument_Name
     (Member : Struct_Member_Ref; Argument : Argument_Index) return Name_Type
   is
   begin
      Check_Struct_Member (Member);
      Check_Struct_Member_Argument (Member, Argument);
      return Create_Name
        (Member.Id.Struct_Members.all
           (Member.Index).Arguments (Argument).Name.all);
   end Member_Argument_Name;

   --------------------------
   -- Member_Last_Argument --
   --------------------------

   function Member_Last_Argument
     (Member : Struct_Member_Ref) return Any_Argument_Index is
   begin
      Check_Struct_Member (Member);
      return Member.Id.Struct_Members.all (Member.Index).Last_Argument;
   end Member_Last_Argument;

   -----------------
   -- Eval_Member --
   -----------------

   function Eval_Member
     (Value     : Value_Ref;
      Member    : Struct_Member_Ref;
      Arguments : Value_Ref_Array := (1 .. 0 => No_Value_Ref))
      return Value_Ref
   is
      Id           : Language_Id;
      T            : Type_Ref;
      Member_Found : Boolean;
      Args_Count   : Any_Argument_Index;
   begin
      --  Check that we have a struct value

      Check_Value (Value);
      Id := Value.Value.Id;
      T := Type_Of (Value);
      Check_Struct_Type (T);

      --  Check that we have a valid member for it

      Check_Struct_Member (Member);
      Check_Same_Language (Id, Member.Id);
      Member_Found := False;
      for M of Members (T) loop
         if M = Member then
            Member_Found := True;
         end if;
      end loop;
      if not Member_Found then
         raise Precondition_Failure with
           Debug_Name (T) & " does not have the " & Debug_Name (Member)
           & " member";
      end if;

      --  Check that the arguments match Member

      Args_Count := Member_Last_Argument (Member);
      if Arguments'Length /= Args_Count then
         raise Precondition_Failure with
           Debug_Name (T) & " takes" & Args_Count'Image
           & " arguments but got" & Natural'Image (Arguments'Length)
           & " values";
      end if;
      for I in 1 .. Args_Count loop
         declare
            A : Value_Ref renames
              Arguments (Arguments'First + Natural (I) - 1);
            Arg_Type : constant Type_Ref := Member_Argument_Type (Member, I);
         begin
            Check_Value (A);
            Check_Same_Language (Id, A.Value.Id);
            Check_Value_Type (A, To_Index (Arg_Type));
         end;
      end loop;

      --  Finally evaluate the member. TODO??? For now, we only support struct
      --  members.

      if Value.Value.all in Base_Internal_Struct_Value'Class then
         pragma Assert (Arguments'Length = 0);
         declare
            V : constant Base_Internal_Struct_Value_Access :=
              Base_Internal_Struct_Value_Access (Value.Value);
         begin
            return Create_Value (Id, +V.Eval_Member (Member.Index));
         end;
      else
         raise Program_Error;
      end if;
   end Eval_Member;

end Langkit_Support.Generic_API.Introspection;
