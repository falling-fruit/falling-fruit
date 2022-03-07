<h1>Approved types</h1>

<%= link_to '[+] Add type', new_type_path %>

<table id="types_table">
  <thead>
    <tr>
     <th>ID</th>
     <th>PID</th>
     <th>Rank</th>
     <th>Latin</th>
     <th>en</th>
     <th>Cats</th>
     <th>W</th>
     <th>Edit</th>
     <th>Delete</th>
    </tr>
  </thead>
  <tbody>
  <% @types.each do |type| %>
    <tr>
      <td style="text-align:right"><%= type.id %></td>
      <td style="text-align:right"><%= type.parent_id %></td>
      <td>
      <% unless type.taxonomic_rank.blank? %>
        <%= type.taxonomic_rank.to_s + " " + Type::Ranks[type.taxonomic_rank] %>
      <% end %>
      </td>
      <td><%= type.scientific_name %> <%= "(#{type.scientific_synonyms})" unless type.scientific_synonyms.blank? %></td>
      <td>
       <%= type.en_name %>
       <%= "(#{type.en_synonyms})" unless type.en_synonyms.blank? %>
      </td>
      <td><%= mask_to_array(type.category_mask,Type::Categories).join(", ") %></td>
      <td style="text-align:center;">
      <% unless type.wikipedia_url.blank? %>
        <a href="<%= type.wikipedia_url %>" target="_blank">W</a>
      <% end %>
      </td>
      <td><%= link_to 'Edit', edit_type_path(type) %></td>
      <td><%= link_to 'Delete', type, method: :delete, data: { confirm: 'Are you sure?' } %></td>
    </tr>
  <% end %>
  </tbody>
</table>

<script type="text/javascript" charset="utf-8">
  jQuery(document).ready(function(){
    jQuery('#types_table').dataTable({
      "aaSorting": [[3, "asc"], [2, "asc"], [4, "asc"]],
      "bPaginate": false
    });
  });
</script>
