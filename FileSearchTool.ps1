Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'File Search Tool'
$form.Width = 650
$form.Height = 500
$form.AutoSizeMode = 'GrowAndShrink'
$form.StartPosition = 'CenterScreen'
# Handle form resize to adjust controls dynamically
$form.add_Resize({
    # Calculate new widths based on form size
    $newWidth = $form.ClientSize.Width - 20  # Assuming 20 is the combined left and right margin
    $newButtonYPosition = $progressBar.Location.Y + $progressBar.Height + 10  # 10 pixels below the progress bar

    # Adjust controls widths and positions
    $comboBox1.Width = $newWidth
    $textBox2.Width = $newWidth
    $progressBar.Width = $newWidth
    $listBox.Width = $newWidth
    $searchButton.Location = New-Object System.Drawing.Point(10, $newButtonYPosition)
    $cancelButton.Location = New-Object System.Drawing.Point(100, $newButtonYPosition)
})

# Initial setup and rest of your script follows...


$label1 = New-Object System.Windows.Forms.Label
$label1.Location = New-Object System.Drawing.Point(10,20)
$label1.Size = New-Object System.Drawing.Size(280,20)
$label1.Text = 'Enter the folder path:'

$comboBox1 = New-Object System.Windows.Forms.ComboBox
$comboBox1.Location = New-Object System.Drawing.Point(10,40)
$comboBox1.Size = New-Object System.Drawing.Size(580,20)
$comboBox1.AutoCompleteMode = 'SuggestAppend'
$comboBox1.AutoCompleteSource = 'FileSystemDirectories'
$comboBox1.Text = 'C:\Users\vkalakota\Documents\Temp\'

$label2 = New-Object System.Windows.Forms.Label
$label2.Location = New-Object System.Drawing.Point(10,70)
$label2.Size = New-Object System.Drawing.Size(280,20)
$label2.Text = 'Enter the search string:'

$textBox2 = New-Object System.Windows.Forms.TextBox
$textBox2.Location = New-Object System.Drawing.Point(10,90)
$textBox2.Size = New-Object System.Drawing.Size(580,20)

$caseSensitiveCheckbox = New-Object System.Windows.Forms.CheckBox
$caseSensitiveCheckbox.Location = New-Object System.Drawing.Point(10,320)
$caseSensitiveCheckbox.Size = New-Object System.Drawing.Size(200,24)
$caseSensitiveCheckbox.Text = 'Case Sensitive'

$fileTypeLabel = New-Object System.Windows.Forms.Label
$fileTypeLabel.Location = New-Object System.Drawing.Point(220,320)
$fileTypeLabel.Size = New-Object System.Drawing.Size(100,20)
$fileTypeLabel.Text = 'File type:'

$fileTypeComboBox = New-Object System.Windows.Forms.ComboBox
$fileTypeComboBox.Location = New-Object System.Drawing.Point(320,320)
$fileTypeComboBox.Size = New-Object System.Drawing.Size(121,21)
$fileTypeComboBox.Items.AddRange(@('.txt', '.log', '.xml', '*.*'))

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,350)
$progressBar.Size = New-Object System.Drawing.Size(580,23)

$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(10,120)
$listBox.Size = New-Object System.Drawing.Size(580,200)
$listBox.SelectionMode = 'MultiExtended'

# Create the context menu and menu items
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$copyPathMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$copyPathMenuItem.Text = 'Copy Path'
$copyFileMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$copyFileMenuItem.Text = 'Copy File'

# Add menu items to the context menu
$contextMenu.Items.AddRange(@($copyPathMenuItem, $copyFileMenuItem))

# Handle the Opening event of the context menu
$contextMenu.add_Opening({
    $selected = $listBox.SelectedItems.Count -gt 0
    $copyPathMenuItem.Enabled = $selected
    $copyFileMenuItem.Enabled = $selected
})

# Assign the context menu to the list box
$listBox.ContextMenuStrip = $contextMenu

# Add Click event handlers for menu items
$copyPathMenuItem.Add_Click({
    $selectedItems = $listBox.SelectedItems
    $paths = $selectedItems -join [Environment]::NewLine
    [Windows.Forms.Clipboard]::SetText($paths)
})

$copyFileMenuItem.Add_Click({
    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialogResult = $folderBrowserDialog.ShowDialog()
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        $destination = $folderBrowserDialog.SelectedPath
        $copySuccess = $true
        $copiedFilesCount = 0
        foreach ($item in $listBox.SelectedItems) {
            $fileName = [System.IO.Path]::GetFileName($item)
            $destPath = [System.IO.Path]::Combine($destination, $fileName)
            try {
                Copy-Item -Path $item -Destination $destPath -ErrorAction Stop
                $copiedFilesCount++
            } catch {
                $copySuccess = $false
                break
            }
        }
        if ($copySuccess -and $copiedFilesCount -gt 0) {
            [System.Windows.Forms.MessageBox]::Show("$copiedFilesCount file(s) copied successfully to '$destination'.", 'Success')
        } elseif (-not $copySuccess) {
            [System.Windows.Forms.MessageBox]::Show("An error occurred while copying the files.", 'Error')
        }
    }
})




$contextMenu.Items.Add($copyPathMenuItem)
$contextMenu.Items.Add($copyFileMenuItem)

$listBox.ContextMenuStrip = $contextMenu

$searchButton = New-Object System.Windows.Forms.Button
$searchButton.Location = New-Object System.Drawing.Point(10,380)
$searchButton.Size = New-Object System.Drawing.Size(75,23)
$searchButton.Text = 'Search'
$searchButton.Add_Click({
    $listBox.Items.Clear()
    $progressBar.Value = 0
    $path = $comboBox1.Text
    $searchString = $textBox2.Text
    $caseSensitive = $caseSensitiveCheckbox.Checked

    if ($fileTypeComboBox.SelectedItem -ne $null) {
        $fileType = $fileTypeComboBox.SelectedItem.ToString()
    } else {
        $fileType = '*.*'
    }

    $fileTypeFilter = {
        if ($fileType -eq '*.*') {
            return $_ -is [System.IO.FileInfo]
        } else {
            return $_ -is [System.IO.FileInfo] -and $_.Extension -eq $fileType
        }
    }

    $files = Get-ChildItem -Path $path -Recurse | Where-Object $fileTypeFilter
    $total = $files.Count
    $count = 0
    foreach ($file in $files) {
        $count++
        $progressBar.Value = ($count / $total) * 100
        $selectStringParams = @{
            Path = $file.FullName
            Pattern = $searchString
            Quiet = $true
        }

        # Apply case sensitivity based on the checkbox
        if ($caseSensitive) {
            $selectStringParams['CaseSensitive'] = $true
        }

        if (Select-String @selectStringParams) {
            $listBox.Items.Add($file.FullName)
        }
    }
    if ($listBox.Items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('No files found matching the criteria.', 'Search Results')
    }
    $progressBar.Value = 100
})




$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(100,380)
$cancelButton.Size = New-Object System.Drawing.Size(75,23)
$cancelButton.Text = 'Cancel'
$cancelButton.Add_Click({ $form.Close() })

$form.Controls.Add($label1)
$form.Controls.Add($comboBox1)
$form.Controls.Add($label2)
$form.Controls.Add($textBox2)
$form.Controls.Add($caseSensitiveCheckbox)
$form.Controls.Add($fileTypeLabel)
$form.Controls.Add($fileTypeComboBox)
$form.Controls.Add($progressBar)
$form.Controls.Add($listBox)
$form.Controls.Add($searchButton)
$form.Controls.Add($cancelButton)

$form.ShowDialog()
