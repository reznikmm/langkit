## vim: filetype=makoada

## This file provides templates for the code generation of root AST list types.
## Derived AST list types are handled directly in astnode_types_ada.mako, as
## their definition is much more like the ones of regular AST nodes.

<%def name="public_incomplete_decl(element_type)">

   <%
      elt_type = element_type.name()
      value_type = 'List_{}_Type'.format(elt_type)
      type_name = 'List_{}'.format(elt_type)
   %>

   type ${value_type};
   type ${type_name} is access all ${value_type}'Class;

</%def>

<%def name="public_decl(element_type)">

   <%
      elt_type = element_type.name()
      value_type = 'List_{}_Type'.format(elt_type)
      type_name = 'List_{}'.format(elt_type)
   %>

   type ${value_type} is new ${root_node_value_type} with private;

   function Item
     (Node  : access ${value_type};
      Index : Positive)
      return ${elt_type}
   is (${elt_type} (Node.Child (Index)));
   --  Shortcut for: ${type_name} (Child (Node, Index))

</%def>

<%def name="private_decl(element_type)">

   <%
      list_type = element_type.list_type()
      elt_type = element_type.name()
      pkg_name = 'Lists_{}'.format(elt_type)
      value_type = 'List_{}_Type'.format(elt_type)
      type_name = 'List_{}'.format(elt_type)
      access_type = 'List_{}_Access'.format(elt_type)
   %>

   package ${pkg_name} is new List
     (Node_Kind      => ${list_type.ada_kind_name()},
      Node_Kind_Name => "${list_type.repr_name()}",
      Node_Type      => ${elt_type}_Type,
      Node_Access    => ${elt_type});

   type ${value_type} is
      new ${pkg_name}.List_Type with null record;

   type ${access_type} is access all ${value_type};

   ## Helper generated for properties code. Used in CollectionGet's code
   function Get
     (Node    : access ${value_type}'Class;
      Index   : Integer;
      Or_Null : Boolean := False) return ${element_type.name()};
   --  When Index is positive, return the Index'th element in T. Otherwise,
   --  return the element at index (Size - Index - 1). Index is zero-based.

   ## Helper for properties code
   function Length (Node : access ${value_type}'Class) return Natural is
     (Node.Child_Count);

</%def>

<%def name="body(element_type)">

   <%
      elt_type = element_type.name()
      pkg_name = 'Lists_{}'.format(elt_type)
      type_name = 'List_{}'.format(elt_type)
      value_type = 'List_{}_Type'.format(elt_type)
   %>

   ---------
   -- Get --
   ---------

   function Get
     (Node    : access ${value_type}'Class;
      Index   : Integer;
      Or_Null : Boolean := False) return ${element_type.name()}
   is
      function Absolute_Get
        (L : ${type_name}; Index : Integer)
         return ${element_type.name()}
      is
        (${pkg_name}.Node_Vectors.Get_At_Index (L.Vec, Index + 1));
      --  L.Vec is 1-based but Index is 0-based

      function Length (Node : ${type_name}) return Natural is (Node.Length);
      --  Wrapper around the Length primitive to get the compiler happy for the
      --  the package instantiation below.

      function Relative_Get is new Langkit_Support.Relative_Get
        (Item_Type     => ${element_type.name()},
         Sequence_Type => ${type_name},
         Length        => Length,
         Get           => Absolute_Get);

      Result : ${element_type.name()};
   begin
      if Relative_Get (${type_name} (Node), Index, Result) then
         return Result;
      elsif Or_Null then
         return null;
      else
         raise Property_Error with "out-of-bounds AST list access";
      end if;
   end Get;

</%def>
