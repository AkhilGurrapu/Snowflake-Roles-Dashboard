import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col
import networkx as nx
import matplotlib.pyplot as plt

# Get the current session
session = get_active_session()

# Fetch roles data
@st.cache_data
def get_roles():
    roles_df = session.table('SNOWFLAKE.ACCOUNT_USAGE.ROLES').select('NAME')
    roles = roles_df.collect()
    return [row['NAME'] for row in roles]

# Fetch grants data
@st.cache_data
def get_grants():
    grants_df = session.table('SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES').filter(col('DELETED_ON').is_null())
    return grants_df.select('GRANTEE_NAME', 'PRIVILEGE', 'NAME').collect()

role_names = get_roles()
grants = get_grants()

# Create a directed graph
G = nx.DiGraph()

# Add nodes and edges to the graph
for grant in grants:
    grantee = grant['GRANTEE_NAME']
    privilege = grant['PRIVILEGE']
    name = grant['NAME']
    G.add_edge(grantee, name, privilege=privilege)

# Streamlit app
st.title("Snowflake Role Grants Visualization")

# Role selection
selected_role = st.selectbox("Select a role:", role_names)

# Visualize the graph
if selected_role:
    st.subheader(f"Grants for {selected_role}")
    
    # Create a subgraph for the selected role
    subgraph = nx.ego_graph(G, selected_role, radius=2)
    
    # Draw the graph
    fig, ax = plt.subplots(figsize=(12, 8))
    pos = nx.spring_layout(subgraph)
    nx.draw(subgraph, pos, ax=ax, with_labels=True, node_color='lightblue', 
            node_size=3000, font_size=8, font_weight='bold')
    
    # Add edge labels
    edge_labels = nx.get_edge_attributes(subgraph, 'privilege')
    nx.draw_networkx_edge_labels(subgraph, pos, edge_labels=edge_labels, font_size=6)
    
    st.pyplot(fig)

    # Display grants information
    st.subheader("Grants Details")
    for grant in grants:
        if grant['GRANTEE_NAME'] == selected_role or grant['NAME'] == selected_role:
            st.write(f"{grant['GRANTEE_NAME']} has {grant['PRIVILEGE']} on {grant['NAME']}")

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
