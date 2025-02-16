import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col
import networkx as nx
import matplotlib.pyplot as plt
import pandas as pd

# Get the current session
session = get_active_session()

# Fetch roles data with role types
@st.cache_data
def get_roles():
    roles_df = session.table('SNOWFLAKE.ACCOUNT_USAGE.ROLES').select(
        'NAME', 
        'ROLE_TYPE', 
        'ROLE_INSTANCE_ID'
    )
    roles = roles_df.collect()
    return [(row['NAME'], row['ROLE_TYPE'] if 'ROLE_TYPE' in row else 'ROLE', 
             row['ROLE_INSTANCE_ID'] if 'ROLE_INSTANCE_ID' in row else None) for row in roles]

# Fetch grants data
@st.cache_data
def get_grants():
    grants_df = session.table('SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES').filter(col('DELETED_ON').is_null())
    return grants_df.select('GRANTEE_NAME', 'PRIVILEGE', 'NAME').collect()

roles_data = get_roles()
role_names = [role[0] for role in roles_data]
role_types = {role[0]: role[1] for role in roles_data}
grants = get_grants()

# Create a directed graph
G = nx.DiGraph()

# Add nodes with role type attribute
for role_name, role_type, instance_id in roles_data:
    G.add_node(role_name, role_type=role_type, instance_id=instance_id)

# Add edges to the graph
for grant in grants:
    grantee = grant['GRANTEE_NAME']
    privilege = grant['PRIVILEGE']
    name = grant['NAME']
    G.add_edge(grantee, name, privilege=privilege)

# Define color map for different role types
role_colors = {
    'ROLE': 'lightblue',
    'APPLICATION_ROLE': 'lightgreen',
    'INSTANCE_ROLE': 'lightpink'
}

# Streamlit app
st.title("Snowflake Role Grants Visualization")

# Role type filter
selected_role_type = st.selectbox(
    "Filter by role type:",
    ['All'] + list(set(role_types.values()))
)

# Filtered role names based on type
filtered_roles = role_names if selected_role_type == 'All' else [
    name for name, type_ in role_types.items() if type_ == selected_role_type
]

# Role selection
selected_role = st.selectbox("Select a role:", filtered_roles)

# Visualize the graph
if selected_role:
    st.subheader(f"Grants for {selected_role} ({role_types.get(selected_role, 'Unknown Type')})")
    
    # Create a subgraph for the selected role
    subgraph = nx.ego_graph(G, selected_role, radius=2)
    
    # Draw the graph
    fig, ax = plt.subplots(figsize=(15, 10))  # Increased figure size
    
    # Use a different layout algorithm with more spacing
    pos = nx.spring_layout(subgraph, k=1.5, iterations=50)  # Increased spacing between nodes
    
    # Draw nodes with different colors based on role type
    for role_type in role_colors:
        node_list = [node for node in subgraph.nodes() 
                    if role_types.get(node, 'ROLE') == role_type]
        if node_list:
            nx.draw_networkx_nodes(subgraph, pos, 
                                 nodelist=node_list,
                                 node_color=role_colors[role_type],
                                 node_size=4000,  # Increased node size
                                 alpha=0.7)  # Added transparency
    
    # Draw edges with arrows
    nx.draw_networkx_edges(subgraph, pos, 
                          edge_color='gray',
                          width=1.5,
                          arrowsize=20,
                          alpha=0.6)
    
    # Draw labels with white background for better readability
    labels = nx.draw_networkx_labels(subgraph, pos, 
                                   font_size=9,
                                   font_weight='bold')
    
    # Add white background to labels for better readability
    for label in labels.values():
        label.set_bbox(dict(facecolor='white', 
                           edgecolor='none',
                           alpha=0.7,
                           pad=0.5))
    
    # Add edge labels with white background
    edge_labels = nx.get_edge_attributes(subgraph, 'privilege')
    edge_label_pos = nx.draw_networkx_edge_labels(
        subgraph, pos,
        edge_labels=edge_labels,
        font_size=8,
        bbox=dict(facecolor='white',
                 edgecolor='none',
                 alpha=0.7,
                 pad=0.5)
    )
    
    # Add legend with larger markers
    legend_elements = [plt.Line2D([0], [0], 
                                 marker='o', 
                                 color='w',
                                 markerfacecolor=color, 
                                 label=role_type,
                                 markersize=15,  # Increased marker size
                                 alpha=0.7)
                      for role_type, color in role_colors.items()]
    
    ax.legend(handles=legend_elements, 
             loc='center left',
             bbox_to_anchor=(1, 0.5),
             fontsize=10,
             title='Role Types',
             title_fontsize=12)
    
    # Remove axes
    ax.set_axis_off()
    
    # Add some padding around the graph
    plt.tight_layout()
    
    st.pyplot(fig)

    # Display grants information in a more structured way
    st.subheader("Grants Details")
    
    # Create two columns for better organization
    grants_for_role = []
    grants_from_role = []
    
    for grant in grants:
        if grant['GRANTEE_NAME'] == selected_role:
            grants_from_role.append(
                f"➡️ Has {grant['PRIVILEGE']} on {grant['NAME']} "
                f"({role_types.get(grant['NAME'], 'Unknown Type')})"
            )
        elif grant['NAME'] == selected_role:
            grants_for_role.append(
                f"⬅️ Granted to {grant['GRANTEE_NAME']} "
                f"({role_types.get(grant['GRANTEE_NAME'], 'Unknown Type')}) "
                f"with {grant['PRIVILEGE']} privilege"
            )
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.write("**Privileges Granted From This Role:**")
        for grant in grants_from_role:
            st.write(grant)
            
    with col2:
        st.write("**Privileges Granted To This Role:**")
        for grant in grants_for_role:
            st.write(grant)

# Additional information about SNOWFLAKE database roles
st.subheader("SNOWFLAKE Database Roles")
st.write("""
The ACCOUNT_USAGE schema has four predefined SNOWFLAKE database roles, each granted the SELECT privilege on specific views:

1. OBJECT_VIEWER: Provides visibility into object metadata.
2. USAGE_VIEWER: Provides visibility into historical usage information.
3. GOVERNANCE_VIEWER: Provides visibility into policy-related information.
4. SECURITY_VIEWER: Provides visibility into security-based information.

These roles can be granted to other roles to provide access to specific subsets of views in the SNOWFLAKE database.
""")

st.subheader("Granting SNOWFLAKE Database Roles")
st.write("""
To grant a SNOWFLAKE database role to a custom role:

1. Create a custom role (if not already created).
2. Grant the desired SNOWFLAKE database role to the custom role.
3. Grant the custom role to a user.

Example:
-- Create a custom role
CREATE ROLE CAN_VIEWMD COMMENT = 'This role can view metadata per SNOWFLAKE database role definitions';
-- Grant the OBJECT_VIEWER role to the custom role
GRANT DATABASE ROLE SNOWFLAKE.OBJECT_VIEWER TO ROLE CAN_VIEWMD;
-- Grant the custom role to a user
GRANT ROLE CAN_VIEWMD TO USER your_username;

This allows fine-grained control over access to ACCOUNT_USAGE views[1][4].
""")
