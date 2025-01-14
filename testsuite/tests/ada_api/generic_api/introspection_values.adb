with Ada.Exceptions; use Ada.Exceptions;
with Ada.Text_IO;    use Ada.Text_IO;

with GNATCOLL.GMP.Integers; use GNATCOLL.GMP.Integers;

with Langkit_Support.Errors;      use Langkit_Support.Errors;
with Langkit_Support.Generic_API; use Langkit_Support.Generic_API;
with Langkit_Support.Generic_API.Analysis;
use Langkit_Support.Generic_API.Analysis;
with Langkit_Support.Generic_API.Introspection;
use Langkit_Support.Generic_API.Introspection;
with Langkit_Support.Slocs;       use Langkit_Support.Slocs;

with Libfoolang.Generic_API;

procedure Introspection_Values is

   Id : Language_Id renames Libfoolang.Generic_API.Foo_Lang_Id;

   procedure Put_Title (Label : String);
   --  Print a section title

   procedure Put_Exc (Exc : Exception_Occurrence);
   --  Print info about the given exception occurence

   procedure Inspect (Value : Value_Ref);
   procedure Check_Match (Value : Value_Ref; T : Type_Ref);
   --  Helpers to test value primitives

   function Starts_With (S, Prefix : String) return Boolean
   is (S'Length >= Prefix'Length
       and then S (S'First .. S'First + Prefix'Length - 1) = Prefix);
   --  Return whether ``S`` starts with the ``Prefix`` substring

   function Ends_With (S, Suffix : String) return Boolean
   is (S'Length >= Suffix'Length
       and then S (S'Last - Suffix'Length + 1 .. S'Last) = Suffix);
   --  Return whether ``S`` ends with the ``Suffix`` substring

   ---------------
   -- Put_Title --
   ---------------

   procedure Put_Title (Label : String) is
   begin
      Put_Line (Label);
      Put_Line ((Label'Range => '='));
      New_Line;
   end Put_Title;

   -------------
   -- Put_Exc --
   -------------

   procedure Put_Exc (Exc : Exception_Occurrence) is
   begin
      Put_Line (Exception_Name (Exc) & ": " & Exception_Message (Exc));
   end Put_Exc;

   -------------
   -- Inspect --
   -------------

   procedure Inspect (Value : Value_Ref) is
      Img : constant String := Image (Value);
   begin
      --  Print the debug image for this value. The image for analysis units
      --  contains an absolute path, which is inconvenient for automatic
      --  testing: try to extract the invariant part just to check that it is
      --  sensible.
      Put ("Inspect: ");
      if Value /= No_Value_Ref
         and then Debug_Name (Type_Of (Value)) = "AnalysisUnit"
         and then As_Unit (Value) /= No_Lk_Unit
      then
         declare
            Prefix : constant String := "<Unit for ";
            Suffix : constant String := "example.txt>";
         begin
            if Starts_With (Img, Prefix) and then Ends_With (Img, Suffix) then
               Put_Line (Prefix & Suffix);
            else
               raise Program_Error;
            end if;
         end;
      else
         Put_Line (Img);
      end if;

      Put ("  Type_Of: ");
      declare
         T : Type_Ref;
      begin
         T := Type_Of (Value);
         Put_Line (Debug_Name (T));
      exception
         when Exc : Precondition_Failure =>
            Put_Exc (Exc);
      end;
   end Inspect;

   -----------------
   -- Check_Match --
   -----------------

   procedure Check_Match (Value : Value_Ref; T : Type_Ref) is
   begin
      Put (Image (Value) & " matches " & Debug_Name (T) & "? ");
      if Type_Matches (Value, T) then
         Put_Line ("True");
      else
         Put_Line ("False");
      end if;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end Check_Match;

   Ctx : constant Lk_Context := Create_Context (Id);
   U   : constant Lk_Unit := Ctx.Get_From_File ("example.txt");
   N   : constant Lk_Node := U.Root;

   Enum     : Type_Ref := No_Type_Ref;
   Enum_Val : Enum_Value_Ref;
   Value    : Value_Ref;

   Array_Of_Node, Array_Of_Bigint   : Type_Ref;
   Point_Struct, Node_Result_Struct : Type_Ref;

   Node_Result_N, Point_Label : Struct_Member_Ref;

   Int_Type, Bool_Type : Type_Ref;
   False_Bool          : constant Value_Ref := Create_Bool (Id, False);
   True_Bool           : constant Value_Ref := Create_Bool (Id, True);
   Point_Struct_Value  : Value_Ref;

begin
   --  Look for the first enum type (Enum) and build an enum value ref for it
   --  (Enum_Val). Also initialize Array_Of_Node, Array_Of_Bigint,
   --  Point_Struct, Node_Result_Struct and Example_Node.

   for TI in 1 .. Last_Type (Id) loop
      declare
         T  : constant Type_Ref := From_Index (Id, TI);
         DN : constant String := Debug_Name (T);
      begin
         if DN = "BigInt.array" then
            Array_Of_Bigint := T;
         elsif DN = "FooNode.array" then
            Array_Of_Node := T;
         elsif DN = "Point" then
            Point_Struct := T;
         elsif DN = "NodeResult" then
            Node_Result_Struct := T;
         elsif Is_Enum_Type (T) and then Enum = No_Type_Ref then
            Enum := T;
         end if;
      end;
   end loop;
   Enum_Val := From_Index (Enum, 1);

   --  Search for the NodeResult.n and Point.label members

   for MI in 1 .. Last_Struct_Member (Id) loop
      declare
         M  : constant Struct_Member_Ref := From_Index (Id, MI);
         DN : constant String := Debug_Name (M);
      begin
         if DN = "NodeResult.n" then
            Node_Result_N := M;
         elsif DN = "Point.label" then
            Point_Label := M;
         end if;
      end;
   end loop;

   Put_Title ("Value comparisons");

   declare
      type Operands is record
         Left, Right : Value_Ref;
      end record;

      Checks : constant array (Positive range <>) of Operands :=
        ((No_Value_Ref, No_Value_Ref),
         (No_Value_Ref, False_Bool),
         (False_Bool, Create_Bool (Id, False)),
         (True_Bool, False_Bool),
         (False_Bool, Create_Int (Id, 1)));
   begin
      for C of Checks loop
         declare
            Equal : constant Boolean := C.Left = C.Right;
         begin
            Put_Line (Image (C.Left) & " = " & Image (C.Right)
                      & " => " & Equal'Image);
         end;
      end loop;
   end;
   New_Line;

   Put_Title ("Value constructors/getters");

   Inspect (No_Value_Ref);

   Value := Create_Unit (Id, No_Lk_Unit);
   Inspect (Value);
   if As_Unit (Value) /= No_Lk_Unit then
      raise Program_Error;
   end if;

   Value := Create_Unit (Id, U);
   Inspect (Value);
   if As_Unit (Value) /= U then
      raise Program_Error;
   end if;

   declare
      BI : Big_Integer;
   begin
      BI.Set ("9111111111124567890");
      Value := Create_Big_Int (Id, BI);
      Inspect (Value);
      if As_Big_Int (Value) /= BI then
         raise Program_Error;
      end if;
   end;

   Value := Create_Bool (Id, True);
   Inspect (Value);
   if not As_Bool (Value) then
      raise Program_Error;
   end if;
   Value := Create_Bool (Id, False);
   Inspect (Value);
   if As_Bool (Value) then
      raise Program_Error;
   end if;
   Bool_Type := Type_Of (Value);

   Value := Create_Char (Id, 'A');
   Inspect (Value);
   if As_Char (Value) /= 'A' then
      raise Program_Error;
   end if;

   Value := Create_Int (Id, 42);
   Inspect (Value);
   if As_Int (Value) /= 42 then
      raise Program_Error;
   end if;
   Int_Type := Type_Of (Value);

   declare
      SR : constant Source_Location_Range :=
        Langkit_Support.Slocs.Value (String'("1:2-3:4"));
   begin
      Value := Create_Source_Location_Range (Id, SR);
      Inspect (Value);
      if As_Source_Location_Range (Value) /= SR then
         raise Program_Error;
      end if;
   end;

   Value := Create_String (Id, "hello, world!");
   Inspect (Value);
   if As_String (Value) /= "hello, world!" then
      raise Program_Error;
   end if;

   declare
      Token : constant Lk_Token := U.First_Token;
   begin
      Value := Create_Token (Id, Token);
      Inspect (Value);
      if As_Token (Value) /= Token then
         raise Program_Error;
      end if;
   end;

   Value := Create_Symbol (Id, "foo_bar42");
   Inspect (Value);
   if As_Symbol (Value) /= "foo_bar42" then
      raise Program_Error;
   end if;

   Value := Create_Node (Id, No_Lk_Node);
   Inspect (Value);
   if As_Node (Value) /= No_Lk_Node then
      raise Program_Error;
   end if;

   Value := Create_Node (Id, N);
   Inspect (Value);
   if As_Node (Value) /= N then
      raise Program_Error;
   end if;
   New_Line;

   Put_Title ("Enum values introspection");

   Put ("Create_Enum: null enum value ref: ");
   begin
      Value := Create_Enum (No_Enum_Value_Ref);
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Value := Create_Enum (Enum_Val);
   Inspect (Value);
   if As_Enum (Value) /= Enum_Val then
      raise Program_Error;
   end if;
   New_Line;

   Put_Title ("Array values introspection");

   Put ("Create_Array: null array type: ");
   begin
      Value := Create_Array (No_Type_Ref, (1 .. 0 => <>));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Create_Array: null value reference: ");
   begin
      Value := Create_Array (Array_Of_Node, (1 => No_Value_Ref));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Create_Array: value type mismatch: ");
   begin
      Value := Create_Array (Array_Of_Node, (1 => True_Bool));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Value := Create_Array (Array_Of_Node, (1 .. 0 => <>));
   Inspect (Value);
   if Array_Length (Value) /= 0
      or else As_Array (Value)'Length /= 0
   then
      raise Program_Error;
   end if;

   declare
      N : constant Value_Ref := Create_Node (Id, No_Lk_Node);
   begin
      Value := Create_Array (Array_Of_Node, (1 => N));
      Inspect (Value);
      if Array_Length (Value) /= 1
         or else As_Array (Value)'Length /= 1
         or else Array_Item (Value, 1) /= N
      then
         raise Program_Error;
      end if;
   end;

   Put ("As_Array: null value: ");
   declare
      Dummy : Integer;
   begin
      Dummy := As_Array (No_Value_Ref)'Length;
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("As_Array: value type mismatch: ");
   declare
      Dummy : Integer;
   begin
      Dummy := As_Array (True_Bool)'Length;
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Array_Length: null value: ");
   declare
      Dummy : Integer;
   begin
      Dummy := Array_Length (No_Value_Ref);
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Array_Length: value type mismatch: ");
   declare
      Dummy : Integer;
   begin
      Dummy := Array_Length (True_Bool);
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Array_Item: null value: ");
   begin
      Value := Array_Item (No_Value_Ref, 1);
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Array_Item: value type mismatch: ");
   begin
      Value := Array_Item (True_Bool, 1);
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;
   New_Line;

   Put_Line ("Array_Item: index checks");
   declare
      I1 : constant Value_Ref := Create_Big_Int (Id, Make ("10"));
      I2 : constant Value_Ref := Create_Big_Int (Id, Make ("20"));
      I3 : constant Value_Ref := Create_Big_Int (Id, Make ("30"));
      A  : constant Value_Ref :=
        Create_Array (Array_Of_Bigint, (I1, I2, I3));

      Item    : Value_Ref;
      Success : Boolean;
   begin
      Put_Line ("  array: " & Image (A));
      for I in 1 .. 5 loop
         Put ("  (" & I'Image & "): ");
         begin
            Item := Array_Item (A, I);
            Success := True;
         exception
            when Exc : Precondition_Failure =>
               Put_Exc (Exc);
               Success := False;
         end;
         if Success then
            Put_Line (Image (Item));
         end if;
      end loop;
   end;
   New_Line;

   Put_Title ("Struct values introspection");

   Put ("Create_Struct: null struct type: ");
   begin
      Value := Create_Struct (No_Type_Ref, (1 .. 0 => <>));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Create_Struct: invalid struct type: ");
   begin
      Value := Create_Struct (Root_Node_Type (Id), (1 .. 0 => <>));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Create_Struct: null value reference: ");
   begin
      Value := Create_Struct
        (Node_Result_Struct, (Create_Node (Id, No_Lk_Node), No_Value_Ref));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Create_Struct: value type mismatch: ");
   begin
      Value := Create_Struct
        (Node_Result_Struct, (Create_Node (Id, No_Lk_Node), False_Bool));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Create_Struct: value count mismatch: ");
   begin
      Value := Create_Struct
        (Node_Result_Struct, (1 => Create_Node (Id, No_Lk_Node)));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   declare
      X, Y : Big_Integer;
   begin
      X.Set ("10");
      Y.Set ("20");
      Point_Struct_Value := Create_Struct
        (Point_Struct, (Create_String (Id, "hello world!"),
                        Create_Big_Int (Id, X),
                        Create_Big_Int (Id, Y)));
   end;
   Inspect (Point_Struct_Value);

   Put ("Eval_Member: null struct type: ");
   begin
      Value := Eval_Member (No_Value_Ref, Point_Label);
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Eval_Member: invalid struct type: ");
   begin
      Value := Eval_Member (True_Bool, Point_Label);
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Eval_Member: no such member: ");
   begin
      Value := Eval_Member (Point_Struct_Value, Node_Result_N);
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put ("Eval_Member: too many arguments: ");
   begin
      Value := Eval_Member (Point_Struct_Value, Point_Label, (1 => True_Bool));
      raise Program_Error;
   exception
      when Exc : Precondition_Failure =>
         Put_Exc (Exc);
   end;

   Put_Line
     ("Eval_Member: Point_Label on " & Image (Point_Struct_Value) & ":");
   Value := Eval_Member (Point_Struct_Value, Point_Label);
   Inspect (Value);
   New_Line;

   Put_Title ("Type matching");

   Put_Line ("Basic cases:");
   Value := Create_Int (Id, 32);
   Check_Match (Value, Int_Type);
   Check_Match (Value, Bool_Type);
   Value := Create_Node (Id, N);
   Check_Match (Value, Bool_Type);
   New_Line;

   Put_Line ("Nodes:");
   declare
      RT : constant Type_Ref := Root_Node_Type (Id);
      DT : constant Type_Ref := From_Index (Id, Last_Derived_Type (RT));
   begin
      Check_Match (Value, RT);
      Check_Match (Value, DT);

      Value := Create_Node (Id, No_Lk_Node);
      Check_Match (Value, RT);
      Check_Match (Value, DT);
   end;
   New_Line;

   Put_Line ("Error cases:");
   Check_Match (No_Value_Ref, Int_Type);
   Check_Match (Value, No_Type_Ref);
   New_Line;
end Introspection_Values;
