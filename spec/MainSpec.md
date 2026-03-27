# Lightoom Keyword Editor Plugin

## Description/Overview
- Plugin to provide a supplementary editor for lightroom keywords.

## Requirements
- Plugin must be written in Adobe's Lua dialect.
- Plugin is for "Lightroom Classic", version 15.0.1 (current) or later.
- On invocation, the plugin will present a new row with content described below.  The row will allow creation of new keywords, editing of existing keywords, and deletion of existing keywords.
- The plugin will be available only in the lightroom 'Grid' view.
- The plugin will be activated by the Lightroom Command: 'Open GB Keyword Editor'.
- The plugin will act only on selected images in the 'Grid' view.

## Plugin Window Overview
- The plugin window will consist of three sections:
  1. The 'Button Container Panel' at the top.
  2. The 'Keyword list Panel' in the middle.
  3. The 'Recently Used Keywords' panel at the bottom.

These are described the following sections.

## Panels

### Button Container Panel
- Consists of two buttons:
  1. "Create Keyword"
  2. "Close"

- Buttons will be positioned to the right of the panel in a single row.

### Keyword List Panel
- Contains a list of keywords, one keyword per row.
- Keyword row contents - 3 columns
  1. A count of the number of images containing this keyword (Not user editable)
  2. The keyword (user editable)
  3. A clickable delete field. (Use a graphic 'X' for image) (Not user editable)

### Recently Used Keywords Panel
- Contains the last 10 keywords added, as a folded list of buttons.

## Behaviors

### Create Keyword button
- Will add a row to the 'Keyword List' panel and place the cursor at the beginning of the editable keyword field (initially empty). Column 1 will be blank until the keyword is completed, the delete button will be present and active.
  - Will make the added row the current row.

### Close button
- Will close the editor.

### Keyword List Panel row
- All actions are on row items
- Clicking on a row will establish it as the 'currently working row'.
  - A second click on the keyword field will enable editing.
  - The current row will be highlighted with a background color of lightgreen (#90EE90).
  - There is no default current row. The user must click on a row (or create a new row) to make it current.
- User will type in a keyword name in the keyword field, or select a keyword from the "Recently Used" panel by clicking on a specific button.
  - A completion mechanism will scan all available keywords in the Lightroom keyword list (as the user is typing).
    - Eligible items will be displayed in a dropdown list.
      - Limit the eligible items list to 7.
      - Update the list for each character typed.
      - 'Esc' will close the eligible items list and leave it closed until the user either hits 'Enter' or deletes the current row.
    - 'Tab' key will accept the completion and fill in the keyword.
    - 'Enter' key will signal the keyword is complete.
    - If the entered keyword does not exist in the Lightroom keyword list, the plugin will present a 'Confirm New Keyword' alert with 'Ok' or 'Cancel' buttons.
      - Clicking 'Ok' will accept the keyword and the keyword will be added to the Lightroom keyword list, and to the 'Recently Used' panel as a new button at the beginning of the button list.
        - The number of images containing the keyword field will be updated.
      - Clicking 'Cancel' will simply dismiss the dialog and leave the field state as it is, so the user can continue.
    - Else if the keyword does exist on enter, the keyword edit field is returned to display mode (editing disabled), and the 'images containing this keyword' count will be updated.  The count is 'catalog-wide'.
    - The current row remains on the edited item.
- User can edit a keyword contained in an existing row.
  - The behavior described above will apply to an existing row edit.
  - The current row remains on the edited item.
- Clicking on the 'Delete' button (in the row) will do the following:
  - Remove the keywords ONLY FROM THE SELECTED IMAGES.
  - Refresh the list to reflect the current keywords state.
  - The current row will revert to the initial state (no current row).

### Recently Used Panel keyword button
- Clicking a keyword button will enter that keyword in the current keyword row and update the number of images containing the count in the row.
- Clicking a keyword button will reorder the panel's list of buttons, moving the clicked item to the beginning of the list.
  - The app will maintain a click count for each button.  The list will be reordered by the number of clicks a button receives, highest count first.
    - (This information may already be available in Lightroom.)
    