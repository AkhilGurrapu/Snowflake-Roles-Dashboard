# Snowflake Role Grants Visualization

## Overview
This application is a **Streamlit-based tool** designed to visualize and explore role grants in a Snowflake account. It uses Snowflake's `ACCOUNT_USAGE` schema to fetch roles and grants data, builds a directed graph of the relationships, and provides an interactive interface for role-based exploration.

## Features
* **Interactive Role Selection**: Select a role to view its grants and relationships.
* **Graph Visualization**: Displays a directed graph of the selected role's grants, showing connections between roles and privileges.
* **Grants Details**: Provides detailed information about the privileges granted to or by the selected role.
* **Snowflake Roles Information**: Includes documentation on predefined Snowflake roles and how to manage them.

## Requirements
To run this application, you need:

1. Python 3.8 or higher
2. The following Python libraries:
   * `streamlit`
   * `snowflake-snowpark-python`
   * `networkx`
   * `matplotlib`

## Installation
1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd <repository-folder>
   ```

2. Install dependencies:
   ```bash
   pip install streamlit snowflake-snowpark-python networkx matplotlib
   ```

3. Configure your Snowflake connection using the Snowflake Python Connector.

## Usage
1. Run the Streamlit app:
   ```bash
   streamlit run app.py
   ```

2. Open the provided local URL in your browser.
3. Select a role from the dropdown menu to visualize its grants and explore its relationships.

## Application Workflow

### Fetching Data
The app fetches data from Snowflake's `ACCOUNT_USAGE` schema:
* **Roles**: Retrieved from `SNOWFLAKE.ACCOUNT_USAGE.ROLES`
* **Grants**: Retrieved from `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES`

### Graph Construction
A directed graph is built using NetworkX:
* **Nodes**: Represent roles
* **Edges**: Represent grants between roles, annotated with privileges

### Visualization
The graph is visualized using Matplotlib, with nodes representing roles and edges representing grants.

## Additional Information
The app also includes documentation on predefined Snowflake database roles (`OBJECT_VIEWER`, `USAGE_VIEWER`, etc.) and how to grant these roles to custom roles for fine-grained access control.

## Example SQL Commands for Role Management
```sql
-- Create a custom role
CREATE ROLE CAN_VIEWMD 
COMMENT = 'This role can view metadata per SNOWFLAKE database role definitions';

-- Grant the OBJECT_VIEWER role to the custom role
GRANT DATABASE ROLE SNOWFLAKE.OBJECT_VIEWER TO ROLE CAN_VIEWMD;

-- Grant the custom role to a user
GRANT ROLE CAN_VIEWMD TO USER your_username;
```

## Screenshots
1. **Role Selection Dropdown**
2. **Graph Visualization**
3. **Grants Details Table**

## License
This project is licensed under the MIT License.

## Contributing
Contributions are welcome! Please fork the repository and submit a pull request with your changes.
