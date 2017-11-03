<#

.SYNOPSIS

The Marketplace Toolkit script for Microsoft Azure Stack provides service administrators with a UI to create and upload marketplace items to the marketplace in Microsoft Azure Stack.

.DESCRIPTION

The Marketplace Toolkit script provides a UI experience to create and upload marketplace items to the Azure Stack marketplace. The tool consists of PowerShell and XAML. XAML uses the Windows Presentation Foundation to render the UI. 
The toolkit allows you to 
- Create and publish a solution for the marketplace. This accepts any main ARM template and allows you to define the tenant deployment experience, by creating steps, reassinging and re-ordering parameters.
- Create and publish an extension for the marketplace. This creates a marketplace item for a VM Extension template that will surface on the extension tab of a deployed virtual machine.
- Publish an existing package. If you have an existing marketplace item package (.azpkg file), the publish wizard enables an easy wizard to publish the package to the marketplace.

.EXAMPLE

Start the UI to create and upload a Marketplace item to Azure Stack

.\MarketplaceToolkit.ps1

.NOTES

To use the Marketplace Toolkit for Microsoft Azure Stack script you require:

- This script
- The gallerypackager executable (http://www.aka.ms/azurestackmarketplaceitem)
- Access as Azure Atack administrator to the Azure Stack environment. This is only required if you want to publish the generated package to the marketplace. For this you will also need to install the current PowerShell modules to support Azure Stack on the machine that runs this script (https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install).

The Marketplace Toolkit script for Microsoft Azure Stack is based on PowerShell and the Windows Presentation Foundation. It is published in this public repository so you can make improvements to it by submitting a pull request.

#>

#region XAML
$XAML = @'
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:local="clr-namespace:WpfApplication1"
    Title="Marketplace publishing tool for Microsoft Azure Stack" Height="800" Width="1200" BorderThickness="0,0,1,1" BorderBrush="#282D32"
    WindowStartupLocation="CenterScreen" WindowState="Maximized">
    <Grid>
        <DockPanel LastChildFill="True" >
            <StackPanel DockPanel.Dock="Top" Background="#202428">
                <TextBlock Height="40"/>
            </StackPanel>
            <StackPanel DockPanel.Dock="Left" Background="#282D32" >
                <TextBlock Width="60" />
            </StackPanel>
            <Grid DockPanel.Dock="Left" Background="#2e80ab">
                <ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">
                    <DockPanel LastChildFill="False">
                        <!--#region Dashboard-->
                        <Grid x:Name="DashBoard" DockPanel.Dock="Left" Width="600" Background="#2e80ab" Visibility="Visible" >
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="40"/>
                                <ColumnDefinition Width="175"/>
                                <ColumnDefinition Width="5"/>
                                <ColumnDefinition Width="175"/>
                                <ColumnDefinition Width="5"/>
                                <ColumnDefinition Width="175"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="75" />
                                <RowDefinition Height="355" />
                                <RowDefinition Height="5"/>
                                <RowDefinition Height="175"/>
                            </Grid.RowDefinitions>
                            <TextBlock Grid.Row="0" Text="Dashboard" Foreground="White" FontSize="24" Padding="0,15,0,0" HorizontalAlignment="Left" Grid.ColumnSpan="2" Margin="41,0,0,0" />
                            <Rectangle Grid.Row="1" Grid.Column="1" Fill="White" Grid.ColumnSpan="6" />
                            <TextBlock Grid.Row="1" Grid.Column="1" Padding="10" FontSize="18" Grid.ColumnSpan="6" Text="Add your content to the Azure Stack marketplace" />
                            <TextBlock Grid.Row="1" Grid.Column="1" Padding="10,35,10,10" FontSize="14" Grid.ColumnSpan="6" TextWrapping="Wrap"><LineBreak/><Run FontWeight="Bold" Text="Solution "/><LineBreak/><Run Text="Choose this option if you have an Azure Resource Manager IaaS template to add as a marketplace item."/><LineBreak/><LineBreak/><Run FontWeight="Bold" Text="Extension "/><LineBreak/><Run Text="Choose this option if you want to add a VM extension template.  VM extensions allow you to customize virtual machines.  "/><LineBreak/><LineBreak/><Run FontWeight="Bold" Text="Publish "/><LineBreak/><Run Text="Adds a marketplace item package to the Azure Stack marketplace."/></TextBlock>
                            <Button x:Name="Dashboard_Btn_Solution" Grid.Row="3" Grid.Column="1" Background="White" BorderThickness="0" Cursor="Hand">
                                <StackPanel  >
                                    <Image Width="50"  Source="https://msazurermtools.gallerycdn.vsassets.io/extensions/msazurermtools/azurerm-vscode-tools/0.3.2/1474455407991/Microsoft.VisualStudio.Services.Icons.Default" />
                                    <TextBlock Text="Solution" Padding="15" />
                                </StackPanel>
                            </Button>

                            <Button x:Name="Dashboard_Btn_Extension" Grid.Row="3" Grid.Column="3" Background="White" BorderThickness="0" Cursor="Hand">
                                <StackPanel  >
                                    <Image Width="50"  Source="https://ms-vscode.gallerycdn.vsassets.io/extensions/ms-vscode/powershell/0.7.2/1474455550053/Microsoft.VisualStudio.Services.Icons.Default" />
                                    <TextBlock Text="Extension" Padding="15" />
                                </StackPanel>
                            </Button>

                            <Button x:Name="Dashboard_Btn_Publish" Grid.Row="3" Grid.Column="5" Background="White" BorderThickness="0" Cursor="Hand">
                                <StackPanel  >
                                    <Image Width="50"  Source="https://ms-devlabs.gallerycdn.vsassets.io/extensions/ms-devlabs/foldermanagement/1.2.19/1474455222817/Microsoft.VisualStudio.Services.Icons.Default" />
                                    <TextBlock Text="Publish" Padding="15" />
                                </StackPanel>
                            </Button>

                        </Grid>
                        <!--#endregion Dashboard-->
                        <!--#region Blade_Wizard-->
                        <Border x:Name="Blade_Wizard" BorderBrush="#3D4247" BorderThickness="1,0,0,0" Visibility="Collapsed">
                            <Grid DockPanel.Dock="Left" Width="315" Background="White">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="70" />
                                    <RowDefinition  />
                                </Grid.RowDefinitions>
                                <TextBlock Background="#282D32" Grid.Row="0" Text="Create Package" Foreground="White" FontSize="18" Padding="15,10,0,0" />
                                <ScrollViewer VerticalScrollBarVisibility="Auto" Grid.Row="1" >
                                    <StackPanel HorizontalAlignment="Center"  VerticalAlignment="Top"  >

                                        <Button x:Name="Wizard_Btn_Input" Background="#B3EBFB" Width="258" Height="77" BorderBrush="#CCCCCC" BorderThickness="0,0,0,1" HorizontalContentAlignment="Left" >
                                            <StackPanel Orientation="Horizontal" >
                                                <TextBlock Text="1" FontSize="36" Padding="20,0,20,0" FontWeight="SemiBold" />
                                                <StackPanel >
                                                    <TextBlock Text="Input" Padding="0,10,0,3" Width="175"/>
                                                    <TextBlock Text="Text and images" />
                                                </StackPanel>
                                                <TextBlock Text=">" FontSize="24" Padding="0,0,0,3"/>
                                            </StackPanel>
                                        </Button>

                                        <Button x:Name="Wizard_Btn_Parameters" Background="White" Width="258" Height="77" BorderBrush="#CCCCCC" BorderThickness="0,0,0,1" HorizontalContentAlignment="Left" >
                                            <StackPanel Orientation="Horizontal" >
                                                <TextBlock Text="2" FontSize="36" Padding="20,0,20,0" FontWeight="SemiBold" />
                                                <StackPanel >
                                                    <TextBlock Text="Parameters" Padding="0,10,0,3" Width="175"/>
                                                    <TextBlock Text="Deployment template" />
                                                </StackPanel>
                                                <TextBlock Text=">" FontSize="24" Padding="0,0,0,3"/>
                                            </StackPanel>
                                        </Button>

                                        <Button x:Name="Wizard_Btn_Publish" Background="White" Width="258" Height="77" BorderBrush="#CCCCCC" BorderThickness="0,0,0,1" HorizontalContentAlignment="Left" >
                                            <StackPanel Orientation="Horizontal" >
                                                <TextBlock Text="3" FontSize="36" Padding="20,0,20,0" FontWeight="SemiBold" />
                                                <StackPanel >
                                                    <TextBlock Text="Publish" Padding="0,10,0,3" Width="175"/>
                                                    <TextBlock Text="Upload package" />
                                                </StackPanel>
                                                <TextBlock Text=">" FontSize="24" Padding="0,0,0,3"/>
                                            </StackPanel>
                                        </Button>

                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                        <!--#endregion Blade_Wizard-->
                        <!--#region Blade_Input-->
                        <Border x:Name="Blade_Input" BorderBrush="#3D4247" BorderThickness="1,0,0,0" Visibility="Collapsed">
                            <Grid DockPanel.Dock="Left" Width="315" Background="White">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="70" />
                                    <RowDefinition  />
                                </Grid.RowDefinitions>
                                <TextBlock Background="#282D32" Grid.Row="0" Text="Text and images" Foreground="White" FontSize="18" Padding="15,10,0,0" />
                                <Button x:Name="Input_Btn_Close" Content="X" HorizontalAlignment="Right" Background="#282D32" Foreground="#a9abad" BorderThickness="0" Width="30" Height="30" Padding="5" FontSize="16" FontWeight="SemiBold"  VerticalAlignment="Top" VerticalContentAlignment="Center"/>
                                <ScrollViewer VerticalScrollBarVisibility="Auto" Grid.Row="1" >
                                    <StackPanel HorizontalAlignment="Left"  VerticalAlignment="Top" Margin="25,15,0,25" >
                                        <Button x:Name="Input_Btn_Preview" Background="White" Width="258" Height="61" BorderBrush="#CCCCCC" BorderThickness="0,1,0,1" HorizontalContentAlignment="Left" >
                                            <StackPanel Orientation="Horizontal" >
                                                <StackPanel >
                                                    <TextBlock Text="Preview" Padding="0,0,0,3" Width="240"/>
                                                    <TextBlock Text="UI experience" FontSize="14" />
                                                </StackPanel>
                                                <TextBlock Text=">" FontSize="24" Padding="0,0,0,3"/>
                                            </StackPanel>
                                        </Button>
                                        <Label x:Name="Input_Lbl_ParameterFile" Content="Publisher parameter file" />
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                            <TextBox x:Name="Input_Tbx_ParamFile" Width="190" Height="23"  />
                                            <Button x:Name="Input_Btn_ParamFile" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal" Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Name" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                            <TextBox x:Name="Input_Tbx_Name" Width="258" />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal" Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Publisher" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                            <TextBox x:Name="Input_Tbx_Publisher" Width="258" />
                                            <Button  Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Summary" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                            <TextBox x:Name="Input_Tbx_Summary" Width="258" />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Description" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Width="258" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                            <TextBox x:Name="Input_Tbx_Description" Width="258" Height="60" TextWrapping="WrapWithOverflow" />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                        </StackPanel>

                                        <StackPanel x:Name="Input_Stp_Category" Visibility="Visible">
                                            <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                                <Label Content="*" Foreground="red"/>
                                                <Label Content="Category" />
                                            </StackPanel>
                                            <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                <TextBox x:Name="Input_Tbx_Category" Width="258" />
                                                <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                            </StackPanel>
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Icon 40x40" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                            <TextBox x:Name="Input_Tbx_Icon40" Width="190" Height="23"  />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                            <Button x:Name="Input_Btn_Icon40" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Icon 90x90" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                            <TextBox x:Name="Input_Tbx_Icon90" Width="190" Height="23"  />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                            <Button x:Name="Input_Btn_Icon90" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Icon 115x115" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                            <TextBox x:Name="Input_Tbx_Icon115" Width="190" Height="23"  />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                            <Button x:Name="Input_Btn_Icon115" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Icon 255x115" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                            <TextBox x:Name="Input_Tbx_Icon255" Width="190" Height="23"  />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                            <Button x:Name="Input_Btn_Icon255" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Screenshot 533x324" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                            <TextBox x:Name="Input_Tbx_Screenshot" Width="190" Height="23"  />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                            <Button x:Name="Input_Btn_Screenshot" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                        </StackPanel>
                                        <Border BorderBrush="#CCCCCC" BorderThickness="0,1,0,0" Margin="0,30,0,0">
                                            <Button x:Name="Input_Btn_OK" Width="60" Height="23" Content="OK" HorizontalAlignment="Right" Margin="0,15,0,0"></Button>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                        <!--#endregion Blade_Input-->
                        <!--#region Blade_Preview -->
                        <Border x:Name="Blade_Preview" BorderBrush="#3D4247" BorderThickness="1,0,0,0" Visibility="Collapsed">
                            <Grid DockPanel.Dock="Left" Width="585" Background="White">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="70" />
                                    <RowDefinition  />
                                </Grid.RowDefinitions>
                                <Rectangle Grid.Row="0" Fill="#282D32" />
                                <StackPanel Grid.Row="0" Orientation="Horizontal">
                                    <Image x:Name="Preview_Img_Icon40" Width="60" Height="60" Margin="25,4,0,0"/>
                                    <StackPanel>
                                        <TextBlock x:Name="Preview_Tbl_Name" Grid.Row="0" Text="[Name]" Foreground="White" FontSize="18" Padding="7,5,0,0"/>
                                        <TextBlock x:Name="Preview_Tbl_Publisher" Grid.Row="0" Text="[Publisher]" Foreground="#a9abad" FontSize="10" Padding="7,0,0,0"/>
                                    </StackPanel>
                                </StackPanel>
                                <Button x:Name="Preview_Btn_Close" Content="X" HorizontalAlignment="Right" Background="#282D32" Foreground="#a9abad" BorderThickness="0" Width="30" Height="30" Padding="5" FontSize="16" FontWeight="SemiBold"  VerticalAlignment="Top" VerticalContentAlignment="Center"/>
                                <ScrollViewer VerticalScrollBarVisibility="Auto" Grid.Row="1">
                                    <StackPanel HorizontalAlignment="Left"  VerticalAlignment="Top" >
                                        <TextBlock x:Name="Preview_Tbl_Description" TextWrapping="Wrap" Text="[Description]" Width="535"  Margin="25,10,25,15"/>
                                        <Border BorderBrush="#CCCCCC" BorderThickness="0,1,0,1" Margin="15,10,15,15">
                                            <Image x:Name="Preview_Img_Screenshot" Width="533" Height="324" Margin="0,15,0,15" ></Image>
                                        </Border>
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition/>
                                                <RowDefinition/>
                                            </Grid.RowDefinitions>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="180"/>
                                                <ColumnDefinition />
                                            </Grid.ColumnDefinitions>
                                            <TextBlock Grid.Row="0" Grid.Column="0" Text="PUBLISHER" Margin="25,0,0,0"/>
                                            <TextBlock Grid.Row="1" Grid.Column="0" Text="USEFUL LINKS" Margin="25,0,0,0"/>
                                            <TextBlock x:Name="Preview_Tbl_Publisher2" Grid.Row="0" Grid.Column="1" Text="[Publisher]" />
                                            <TextBlock x:Name="Preview_Tbl_Links" Grid.Row="1" Grid.Column="1" Text="[Links]" VerticalAlignment="Center"/>
                                        </Grid>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                        <!--#endregion Blade_Preview -->
                        <!--#region Blade_Params -->
                        <Border x:Name="Blade_Params" BorderBrush="#3D4247" BorderThickness="1,0,0,0" Visibility="Collapsed">
                            <Grid DockPanel.Dock="Left" Width="315" Background="White">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="70" />
                                    <RowDefinition  />
                                </Grid.RowDefinitions>
                                <TextBlock Background="#282D32" Grid.Row="0" Text="Parameters" Foreground="White" FontSize="18" Padding="15,10,0,0"/>
                                <Button x:Name="Params_Btn_Close" Content="X" HorizontalAlignment="Right" Background="#282D32" Foreground="#a9abad" BorderThickness="0" Width="30" Height="30" Padding="5" FontSize="16" FontWeight="SemiBold"  VerticalAlignment="Top" VerticalContentAlignment="Center"/>
                                <ScrollViewer VerticalScrollBarVisibility="Auto" Grid.Row="1">
                                    <StackPanel HorizontalAlignment="Left"  VerticalAlignment="Top" Margin="25,15,0,25"  >

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Deployment template" />
                                        </StackPanel>
                                        <Border BorderBrush="#CCCCCC" BorderThickness="0,0,0,1">
                                            <StackPanel Orientation="Horizontal" Margin="0,0,0,15" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                                <TextBox x:Name="Params_Tbx_Template" Width="190" Height="23"  />
                                                <Button x:Name="Params_Btn_Template_Error" Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                <Button x:Name="Params_Btn_Template" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                            </StackPanel>
                                        </Border>
                                        <StackPanel x:Name="Params_Stp_DeploymentWizard">
                                        <Label Content="Deployment wizard" Padding="5,10,0,5" />
                                        <TreeView x:Name="Params_Tree_View" Width="258" MinHeight="23" Margin="0,0,0,15" Padding="0,0,0,3"  />
                                        </StackPanel>
                                        <Border x:Name="Params_Bdr_Steps" BorderBrush="#CCCCCC" BorderThickness="1" Visibility="Visible">
                                            <StackPanel Background="#F9F9F9F9">
                                                <Label Content="Add or remove steps"   />
                                                <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                    <TextBox x:Name="Params_Tbx_AddStep" Width="180" Height="23" Margin="5,0,0,0"/>
                                                    <Button  x:Name="Params_Btn_AddStep_Error" Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                    <Button x:Name="Params_Btn_AddStep" Content="Add" Width="60" Height="23"  Margin="8,0,0,0"/>
                                                </StackPanel>

                                                <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                    <TextBox x:Name="Params_Tbx_RemoveStep" Width="180" Height="23" Margin="5,0,0,0" Visibility="Hidden"/>
                                                    <Button  x:Name="Params_Btn_RemoveStep_Error" Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                    <Button x:Name="Params_Btn_RemoveStep" Content="Remove" Width="60" Height="23"  Margin="8,0,5,0"/>
                                                </StackPanel>
                                            </StackPanel>
                                        </Border>

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" Margin="0,10,0,0" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Path to AzureGalleryPackager.exe" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,15" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                            <TextBox x:Name="Params_Tbx_Exe" Width="190" Height="23"  />
                                            <Button x:Name="Params_Btn_Exe_Error" Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                            <Button x:Name="Params_Btn_Exe" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                        </StackPanel>

                                        <Border x:Name="Params_Bdr_Create" BorderBrush="#CCCCCC" BorderThickness="0,1,0,0" Margin="0,10,0,0">
                                            <StackPanel Orientation="Horizontal" Margin="0,20,0,8">
                                                <TextBlock Text="Marketplace item"  Width="190" Height="23" Padding="5,2,0,0"/>
                                                <Button x:Name="Params_Btn_Create" Content="Create" Width="60" Height="23"  Margin="8,0,0,0"/>
                                            </StackPanel>
                                        </Border>
                                        <Border x:Name="Params_Bdr_Continue" BorderBrush="#CCCCCC" BorderThickness="0,1,0,0" Margin="0,10,0,0">
                                            <StackPanel Width="258">
                                                <TextBlock Text="The marketplace item package has been created." TextWrapping="Wrap" Margin="0,20,0,0" FontWeight="Bold"  />
                                                <TextBlock Text="Package path" Margin="0,10,0,0" />
                                                <StackPanel Orientation="Horizontal" Margin="0,0,0,15" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                                    <TextBox x:Name="Params_Tbx_PackagePath" Width="190" Height="23"  />
                                                    <Button x:Name="Params_Btn_PathCopy" Content="Copy" Width="60" Height="23" Margin="8,0,0,0" />
                                                </StackPanel>
                                                <TextBlock Text="You can now close the wizard or continue to publish the marketplace item (requires access and service administrator credentials to Microsoft Azure Stack)." TextWrapping="Wrap" />
                                                <StackPanel Orientation="Horizontal" Margin="42,20,0,8">
                                                    <Button x:Name="Params_Btn_Stop" Content="Close wizard" Width="100" Height="23"  Margin="8,0,0,0"/>
                                                    <Button x:Name="Params_Btn_Publish" Content="Publish" Width="100" Height="23"  Margin="8,0,0,0"/>
                                                </StackPanel>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                        <!--#endregion Blade_Params -->
                        <!--#region Blade_ParamType -->
                        <Border x:Name="Blade_ParamType" BorderBrush="#3D4247" BorderThickness="1,0,0,0" Visibility="Collapsed">
                            <Grid DockPanel.Dock="Left" Width="315" Background="White">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="70" />
                                    <RowDefinition  />
                                </Grid.RowDefinitions>
                                <TextBlock Background="#282D32" Grid.Row="0" Text="Details" Foreground="White" FontSize="18" Padding="15,10,0,0"/>
                                <ScrollViewer VerticalScrollBarVisibility="Auto" Grid.Row="1">
                                    <StackPanel HorizontalAlignment="Left"  VerticalAlignment="Top" Margin="25,15,0,25"  >
                                        <StackPanel x:Name="ParamType_Stp_Step" Visibility="Collapsed">
                                            <TextBlock Text="Name" />
                                            <Border BorderBrush="#8F8F8F" BorderThickness="0,0,0,1">
                                                <TextBlock x:Name="ParamType_Tbl_Step_Name" Text="" Padding="2" Width="258" Height="23" Background="#E6E6E6" />
                                            </Border>
                                            <TextBlock Text="Label" />
                                            <Border BorderBrush="#8F8F8F" BorderThickness="0,0,0,1">
                                                <TextBlock x:Name="ParamType_Tbl_Step_Label" Text="" Padding="2" Width="258" Height="23" Background="#E6E6E6" />
                                            </Border>

                                        </StackPanel>
                                        <StackPanel x:Name="ParamType_Stp_Param" Visibility="Visible">
                                            <StackPanel x:Name="ParamType_Stp_AssignStep">
                                                <Label Content="Assign param to step"  />
                                                <ComboBox x:Name="ParamType_Drp_Steps" Width="258" Height="23" Margin="0,0,0,8" />
                                            </StackPanel>
                                            <Border BorderBrush="#CCCCCC" BorderThickness="0,1,0,1" >
                                                <StackPanel Orientation="Horizontal" Margin="0,15,0,15">
                                                    <TextBlock Text="Move parameter" Margin="0,0,40,0" VerticalAlignment="Center" />
                                                    <Button x:Name="ParamType_Btn_MoveUp" Width="60" Height="23" Content="Up" Margin="0,0,10,0"></Button>
                                                    <Button x:Name="ParamType_Btn_MoveDown" Width="60" Height="23" Content="Down"></Button>
                                                </StackPanel>
                                            </Border>
                                            <TextBlock Text="Parameter UI Type" Margin="0,8,0,0" />
                                            <Border BorderBrush="#8F8F8F" BorderThickness="0,0,0,1">
                                                <TextBlock x:Name="ParamType_Tbl_uiType" Text="" Padding="2" Width="258" Height="23" Background="#E6E6E6" />
                                            </Border>
                                            <TextBlock Text="Parameter name" />
                                            <Border BorderBrush="#8F8F8F" BorderThickness="0,0,0,1">
                                                <TextBlock x:Name="ParamType_Tbl_ParamName" Text="" Padding="2" Width="258" Height="23" Background="#E6E6E6" />
                                            </Border>
                                            <TextBlock Text="Parameter type" />
                                            <Border BorderBrush="#8F8F8F" BorderThickness="0,0,0,1">
                                                <TextBlock x:Name="ParamType_Tbl_ParamType" Text="" Padding="2" Width="258" Height="23" Background="#E6E6E6" />
                                            </Border>
                                            <StackPanel Visibility="Collapsed">
                                                <StackPanel x:Name="ParamType_Stp_label" >
                                                    <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                                        <Label Content="*" Foreground="red"/>
                                                        <Label Content="Label" />
                                                    </StackPanel>
                                                    <StackPanel Orientation="Horizontal" Width="258" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                        <TextBox x:Name="ParamType_Tbx_label" Width="258" />
                                                        <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                    </StackPanel>
                                                </StackPanel>

                                                <StackPanel x:Name="ParamType_Stp_defaultValue" Visibility="Visible">
                                                    <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                                        <Label Content="*" Foreground="red" Visibility="Collapsed"/>
                                                        <Label Content="DefaultValue" />
                                                    </StackPanel>
                                                    <StackPanel Orientation="Horizontal" Width="258" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                        <TextBox x:Name="ParamType_Tbx_defaultValue" Width="258" />
                                                        <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                    </StackPanel>
                                                </StackPanel>

                                                <StackPanel x:Name="ParamType_Stp_toolTip" Visibility="Visible">
                                                    <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                                        <Label Content="*" Foreground="red" Visibility="Collapsed"/>
                                                        <Label Content="Tooltip" />
                                                    </StackPanel>
                                                    <StackPanel Orientation="Horizontal" Width="258" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                        <TextBox x:Name="ParamType_Tbx_toolTip" Width="258" />
                                                        <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                    </StackPanel>
                                                </StackPanel>

                                                <StackPanel x:Name="ParamType_Stp_Constraints" Visibility="Visible">
                                                    <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                                        <Label Content="*" Foreground="red" Visibility="Collapsed"/>
                                                        <Label Content="Constraints" />
                                                    </StackPanel>
                                                    <StackPanel Orientation="Horizontal" Width="258" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                        <CheckBox x:Name="ParamType_Cbx_Constraints" Width="258" />
                                                        <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                    </StackPanel>
                                                </StackPanel>
                                                <Border BorderBrush="#CCCCCC" BorderThickness="1">
                                                    <StackPanel x:Name="ParamType_Stp_Constraints_All" Background="#F9F9F9F9">
                                                        <StackPanel x:Name="ParamType_Stp_Constraints_Regex" Visibility="Visible">
                                                            <StackPanel Orientation="Horizontal"  Width="248" Height="25" >
                                                                <Label Content="*" Foreground="red" />
                                                                <Label Content="Regex" />
                                                            </StackPanel>
                                                            <StackPanel Orientation="Horizontal" Width="248" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                                <TextBox x:Name="ParamType_Tbx_Constraints_Regex" Width="248" />
                                                                <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                            </StackPanel>
                                                        </StackPanel>

                                                        <StackPanel x:Name="ParamType_Stp_Constraints_validationMessage" Visibility="Visible">
                                                            <StackPanel Orientation="Horizontal"  Width="248" Height="25" >
                                                                <Label Content="*" Foreground="red" />
                                                                <Label Content="Validation Message" />
                                                            </StackPanel>
                                                            <StackPanel Orientation="Horizontal" Width="248" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                                <TextBox x:Name="ParamType_Tbx_Constraints_ValidationMessage" Width="248" />
                                                                <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                            </StackPanel>
                                                        </StackPanel>

                                                    </StackPanel>
                                                </Border>

                                                <StackPanel x:Name="ParamType_Stp_Options" Visibility="Visible">
                                                    <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                                        <Label Content="*" Foreground="red" Visibility="Collapsed"/>
                                                        <Label Content="Options" />
                                                    </StackPanel>
                                                    <StackPanel Orientation="Horizontal" Width="258" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                        <CheckBox x:Name="ParamType_Cbx_Options" Width="258" />
                                                        <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                    </StackPanel>
                                                </StackPanel>
                                                <Border BorderBrush="#CCCCCC" BorderThickness="1">
                                                    <StackPanel x:Name="ParamType_Stp_Options_All" Background="#F9F9F9F9">
                                                        <StackPanel x:Name="ParamType_Stp_Options_Regex" Visibility="Visible">
                                                            <StackPanel Orientation="Horizontal"  Width="248" Height="25" >
                                                                <Label Content="*" Foreground="red" />
                                                                <Label Content="Hide Confirmation" />
                                                            </StackPanel>
                                                            <StackPanel Orientation="Horizontal" Width="248" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                                <ComboBox x:Name="ParamType_Drp_Options_hideConfirmation" Width="248" />
                                                                <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                            </StackPanel>
                                                        </StackPanel>


                                                        <StackPanel x:Name="ParamType_Stp_Options_validationMessage" Visibility="Visible">
                                                            <StackPanel Orientation="Horizontal"  Width="248" Height="25" >
                                                                <Label Content="*" Foreground="red" />
                                                                <Label Content="Validation Message" />
                                                            </StackPanel>
                                                            <StackPanel Orientation="Horizontal" Width="248" Height="23" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                                                <TextBox x:Name="ParamType_Tbx_Options_ValidationMessage" Width="248" />
                                                                <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                                            </StackPanel>
                                                        </StackPanel>

                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>
                                        </StackPanel>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                        <!--#endregion Blade_Params -->
                        <!--#region Blade_Publish -->
                        <Border x:Name="Blade_Publish" BorderBrush="#3D4247" BorderThickness="1,0,0,0" Visibility="Collapsed">
                            <Grid DockPanel.Dock="Left" Width="315" Background="White">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="70" />
                                    <RowDefinition  />
                                </Grid.RowDefinitions>
                                <TextBlock Background="#282D32" Grid.Row="0" Text="Publish" Foreground="White" FontSize="18" Padding="15,10,0,0" />
                                <Button x:Name="Publish_Btn_Close" Content="X" HorizontalAlignment="Right" Background="#282D32" Foreground="#a9abad" BorderThickness="0" Width="30" Height="30" Padding="5" FontSize="16" FontWeight="SemiBold"  VerticalAlignment="Top" VerticalContentAlignment="Center"/>
                                <ScrollViewer VerticalScrollBarVisibility="Auto" Grid.Row="1">
                                    <StackPanel HorizontalAlignment="Left"  VerticalAlignment="Top" Margin="25,15,0,25">

                                        <StackPanel Orientation="Horizontal"  Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Marketplace item package" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647">
                                            <TextBox x:Name="Publish_Tbx_Package" Width="190" Height="23"  />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                            <Button x:Name="Publish_Btn_Package" Content="Browse" Width="60" Height="23" Margin="8,0,0,0" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal" Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Service admin name" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                            <TextBox x:Name="Publish_Tbx_Username" Width="258" />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal" Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Password" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                            <PasswordBox x:Name="Publish_Pwb_Password1" Width="258" />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal" Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="Confirm password" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                            <PasswordBox x:Name="Publish_Pwb_Password2" Width="258" />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                        </StackPanel>

                                        <StackPanel Orientation="Horizontal" Width="258" Height="25" >
                                            <Label Content="*" Foreground="red"/>
                                            <Label Content="API endpoint" />
                                        </StackPanel>
                                        <StackPanel Orientation="Horizontal" Width="258" Height="23" Margin="0,0,0,8" ToolTipService.InitialShowDelay="0" ToolTipService.ShowDuration="2147483647" >
                                            <TextBox x:Name="Publish_Tbx_Endpoint" Width="258" />
                                            <Button Width="15" Content="!" Foreground="White" Background="Red" BorderThickness="1" BorderBrush="Red" Visibility="Collapsed" Cursor="Hand" />
                                        </StackPanel>

                                        <Label Content="Publishing log" Margin="0,10,0,10" />
                                        <ListView x:Name="Publish_Lsv_Log" MinHeight="23" Background="#F9F9F9F9"/>
                                        <Border BorderBrush="#CCCCCC" BorderThickness="0,1,0,0" Margin="0,15,0,0">
                                            <Button x:Name="Publish_Btn_Publish" Width="60" Height="23" Content="Publish" HorizontalAlignment="Right" Margin="0,15,0,0"></Button>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                        <!--#endregion Blade_Upload -->
                    </DockPanel>
                </ScrollViewer>
            </Grid>
        </DockPanel>
    </Grid>
</Window>
'@
#endregion

#region Get XAML and create variables
Add-Type -AssemblyName PresentationFramework

[XML]$XML = $XAML -replace "x:N",'N' 

$Reader = (New-Object System.XML.XMLNodeReader $XML)
$Form = [Windows.Markup.XAMLReader]::Load($Reader)

# Create variables > Load XAML Objects In PowerShell
$XML.SelectNodes("//*[@Name]") | % {Set-Variable -Name "X_$($_.Name)" -Value $Form.FindName($_.Name)}

$timer = new-object 'System.Windows.Threading.DispatcherTimer'
$timer.Interval = [TimeSpan]"0:0:1.00"

#endregion

#region Functions
function F_Regex {
$X_Input_Tbx_Name.Tag = @{'regex'='[ a-zA-Z0-9]{1,80}';'errormessage'='Maximum 80 characters. Can only contain A-Z, a-z, 0-9 and spaces.'}
$X_Input_Tbx_Publisher.Tag = @{'regex'='[ a-zA-Z0-9]{1,20}';'errormessage'='Maximum 30 characters. Can only contain A-Z, a-z, 0-9 and spaces.'}
$X_Input_Tbx_Summary.Tag = @{'regex'='[ a-zA-Z0-9]{1,100}';'errormessage'='Maximum 100 characters. Can only contain A-Z, a-z, 0-9 and spaces.'}
$X_Input_Tbx_Description.Tag = @{'regex'='.{1,5000}';'errormessage'='Maximum 5000 characters.'}
$X_Input_Tbx_Category.Tag = @{'regex'='[- a-zA-Z0-9;]{1,64}';'errormessage'='Maximum 64 characters. Can only contain A-Z, a-z, 0-9, -, ; and spaces.'}
$X_Input_Tbx_Icon40.Tag = @{'errormessage'='The image size must be 40x40.'}
$X_Input_Tbx_Icon90.Tag = @{'errormessage'='The image size must be 90x90.'}
$X_Input_Tbx_Icon115.Tag = @{'errormessage'='The image size must be 115x115.'}
$X_Input_Tbx_Icon255.Tag = @{'errormessage'='The image size must be 255x115.'}
$X_Input_Tbx_Screenshot.Tag = @{'errormessage'='The image size must be 533x324.'}
$X_Params_Tbx_AddStep.Tag = @{'regex'='[ a-zA-Z]{1,20}';'errormessage'='Maximum 20 characters. Can only contain A-Z, a-z and spaces.'}
$X_Publish_Pwb_Password1.Tag = @{'errormessage'='Passwords do not match.'}
$X_Publish_Pwb_Password1.Tag = @{'errormessage'='Passwords do not match.'}
}

function F_Clear {
$X_Input_Tbx_ParamFile.Text = $null
$X_Input_Tbx_Name.Text = $null
$X_Input_Tbx_Publisher.Text = $null
$X_Input_Tbx_SUmmary.Text = $null
$X_Input_Tbx_description.Text = $null
$X_Input_Tbx_category.Text = $null
$X_Input_Tbx_Icon40.Text = $null
$X_Input_Tbx_Icon90.Text = $null
$X_Input_Tbx_Icon115.Text = $null
$X_Input_Tbx_Icon255.Text = $null
$X_Input_Tbx_Screenshot.Text = $null
$X_Preview_Img_Icon40.Source = $null
$X_Preview_Img_Screenshot.Source = $null
$X_Params_Tbx_Template.Text = $null
$X_Params_Tbx_Exe.Text = $null
$X_Params_Tree_View.Tag = $null
$X_Params_Tree_View.Items.Clear()
$X_Params_Bdr_Steps.Visibility = 'Collapsed'
$X_Publish_Tbx_Package.Text = $null
$X_Publish_Tbx_Username.Text = $null
$X_Publish_Pwb_Password1.Password = $null
$X_Publish_Pwb_Password2.Password = $null
$X_Publish_Tbx_Endpoint.Text = $null
$X_Publish_Lsv_Log.Items.Clear()
$timer.Stop()
}

function F_Validation {
Param(
# Conditions
[string]$regex,
[string]$extension, 
[array]$image,
[string]$compare,
[switch]$vmextension,
[switch]$empty,
[switch]$nocondition,
# Input
[string]$field,
[string]$field_value,
[string]$message,
[string]$columnwidth

)

$Script:validation_error = $false

# Validation Conditions
if ($regex){
    if (($field_value.Length -gt 0) -and ($field_value -notmatch "^($regex)$")) { 
        $Script:validation_error = $true 
        }
}
if ($compare){
    if (($field_value.Length -gt 0) -and ($field_value -ne $compare)) { 
        $Script:validation_error = $true 
        $message = "Passwords do not match"
        }
    }
if ($extension){ 
    if ($field_value.Length -gt 0){
        if (test-path $field_value){
            if ((get-item $field_value).Extension -ne $extension){
            $Script:validation_error = $true 
            $message = 'Not a valid file'
            }
        }
        if (!(test-path $field_value)){
            $Script:validation_error = $true 
            $message = 'Not a valid file'
        }
    }
    }
if ($image){
    if (($field_value.Length -gt 0) -and (test-path $field_value)){
        if ((get-item $field_value).Extension -eq $extension){
            $dimensions = [System.Drawing.Image]::Fromfile((Get-Item $field_value))
    
            if (($dimensions.width -ne $image.width) -or ($dimensions.height -ne $image.height)){ 
                $Script:validation_error = $true
                $message = ($message + " The selected image is " + $dimensions.width + "x" + $dimensions.height) 
                }
            }
        }
    }
if ($vmextension){
    if ($Script:PackageType -eq 'Extension'){
        $ContentJSON = Get-Content ($field_value) -Raw
        $params = ($ContentJSON | ConvertFrom-Json).parameters 
        $params = $params.psobject.members | where {$_.membertype -eq 'NoteProperty'}
        if (($params | where {(($_.name -eq 'vmName') -and ($_.value.type -eq 'string')) -or (($_.name -eq 'location') -and ($_.value.type -eq 'string'))}).count -lt 2){ 
        $Script:validation_error = $true 
        $message = 'Required string parameters "vmName" or/and  "location" not found in template'
        }
}
}
if ($nocondition){ 
        $Script:validation_error = $true 
}
if ($empty){
    if ($field_value.length -eq 0) { 
        $message = 'Required field'
        $Script:validation_error = $true 
    }
}

# Validation Actions
$control = Get-Variable $field

if ($Script:validation_error) {
        #parent stackpanel
        $tooltip = new-object System.Windows.Controls.ToolTip
        $tooltip.Background = "#282D32"
        $tooltip.Foreground = "white"
        $tooltip.BorderThickness = 0
        $tooltip.Padding = 15
        $tooltip.HorizontalOffset = -5
        $tooltip.VerticalOffset = -50
        $tooltip.Content = $message
        $tooltip.Placement = "left"
        $control.value.parent.ToolTip = $tooltip
        #child textbox
        $control.value.Width = ([int]$columnwidth - [int]15)
        $control.value.BorderBrush="Red"
        #child button
        $button = $control.value.parent.children | where {$_.GetType().fullname -eq 'System.Windows.Controls.Button' -and $_.Content -eq '!'} 
        $button.visibility = 'Visible'
        }
 else {
        #parent stackpanel
        $control.value.parent.ToolTip = $null
        #child textbox
        $control.value.Width = $columnwidth
        $control.value.BorderBrush="#FFABADB3"
        #child button
        $button = $control.value.parent.children | where {$_.GetType().fullname -eq 'System.Windows.Controls.Button' -and $_.Content -eq '!'} 
        $button.visibility = 'Collapsed'
        }
}

function F_Browse {
Param(
[string]$title,
[string]$filter
)
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	$Script:F_Browse_obj = New-Object System.Windows.Forms.OpenFileDialog
	$Script:F_Browse_obj.Filter = $filter
	$Script:F_Browse_obj.Title = $title
	$Script:F_Browse_obj.ShowDialog()
}

function F_Get_ParamFile {
Param(
  [string]$File
)
Import-Module $File -Force
if ($applicationName) { $X_Input_Tbx_Name.Text = $applicationName }
if ($publisher) { $X_Input_Tbx_Publisher.Text = $publisher }
if ($summary) { $X_Input_Tbx_SUmmary.Text = $summary }
if ($description) { $X_Input_Tbx_description.Text = $description }
if ($category) { $X_Input_Tbx_category.Text = $category }
if ($icon40x40) { $X_Input_Tbx_Icon40.Text = $icon40x40 }
if ($icon90x90) { $X_Input_Tbx_Icon90.Text = $icon90x90 }
if ($icon115x115) { $X_Input_Tbx_Icon115.Text = $icon115x115 }
if ($icon255x115) { $X_Input_Tbx_Icon255.Text = $icon255x115 }
if ($screenshot533x324) { $X_Input_Tbx_Screenshot.Text = $screenshot533x324 }
if ($armTemplate) { $X_Params_Tbx_Template.Text = $armTemplate }
if ($executablePath) { $X_Params_Tbx_Exe.Text = $executablePath }
if ($userName) { $X_Publish_Tbx_Username.Text = $userName }
if ($endpoint) { $X_Publish_Tbx_Endpoint.Text = $endpoint }
$X_Blade_Preview.Visibility = 'Visible'
}

function F_Create_Grid {
Param(
  [string]$File
)

$ContentJSON = Get-Content ($File)
$params = ($ContentJSON | ConvertFrom-Json).parameters 
$params = $params.psobject.properties

if ($Script:PackageType -eq 'Extension'){
    $params = $params | where {($_.name -ne 'vmName' -or $_.value.type -ne 'string') -and ($_.name -ne 'location' -or $_.value.type -ne 'string')}
}

# Initialize the Grid
$Script:Grid = @()

# Initialize counter for generating Parameter tags (used for ordering).
$count = 0

$params | foreach {
    $param = New-Object -TypeName PSObject
    $param | Add-Member -Type NoteProperty -Name header -Value $_.Name
    $param | Add-Member -Type NoteProperty -Name name -Value $_.Name.replace(' ','')
    $param | Add-Member -Type NoteProperty -Name type -Value $_.value.type
    $param | Add-Member -Type NoteProperty -Name defaultValue -Value $_.value.defaultValue
    $param | Add-Member -Type NoteProperty -Name description -Value $_.value.metadata.description
    if ($Script:PackageType -eq 'Solution') {$param | Add-Member -Type NoteProperty -Name step -Value "basics"}
    if ($Script:PackageType -eq 'Extension') {$param | Add-Member -Type NoteProperty -Name step -Value "elements"}
    $param | Add-Member -Type NoteProperty -Name tag -Value $count
    if (($_.value.type -eq 'string') -and (!($_.value.allowedValues))) {  
        $param | Add-Member -Type NoteProperty -Name uiType -Value "Microsoft.Common.TextBox" 
        $param | Add-Member -Type NoteProperty -Name constraints -Value $false
        }
    if (($_.value.type -eq 'string') -and ($_.value.allowedValues)) {  
        $param | Add-Member -Type NoteProperty -Name uiType -Value "Microsoft.Common.DropDown"
        $param | Add-Member -Type NoteProperty -Name constraints -Value $true
        $allowedValues = @()
        $_.value.allowedValues | foreach {
            $allowedValue = New-Object -TypeName PSObject
            $allowedValue | Add-Member -Type NoteProperty -Name label -Value $_
            $allowedValue | Add-Member -Type NoteProperty -Name value -Value $_
            $allowedValues += $allowedValue
            }
        $param | Add-Member -Type NoteProperty -Name allowedValues -Value $allowedValues
        }
    if ($_.value.type -eq 'int') {  
        $param | Add-Member -Type NoteProperty -Name uiType -Value "Microsoft.Common.TextBox" 
        $param | Add-Member -Type NoteProperty -Name constraints -Value $true
        $param | Add-Member -Type NoteProperty -Name regex -Value '^\d+$'
        $param | Add-Member -Type NoteProperty -Name validationMessage -Value 'Only numeric characters are allowed, and it must be a positive value'
        }
    if ($_.value.type -eq 'securestring') {  
        $param | Add-Member -Type NoteProperty -Name uiType -Value "Microsoft.Common.PasswordBox" 
        $param | Add-Member -Type NoteProperty -Name constraints -Value $false
        }

    # Add each param to the grid varaiable
    $Script:Grid += $param
    # Increment the counter with 1
    $count ++
}

}

function F_Create_Tree {
# Start with an empty treeview
$X_Params_Tree_View.items.Clear()
# Clear Dropdown of paramtype details
$X_ParamType_Drp_Steps.items.Clear()

if ($Script:PackageType -eq 'Solution') {
    # Set tag for root of TreeView. This is used for filtering
    $X_Params_Tree_View.tag = '@TreeViewRoot@'
    # Create Default Wizard Step named "Basics". Tag value is used for ordering.
    $Script:basics = New-Object System.Windows.Controls.TreeViewItem
    $Script:basics.header = "Basics"
    $Script:basics.name = "Basics"
    $Script:basics.tag = "0"
    # Expand the "Basics" treeview item by default
    $script:basics.IsExpanded = $true
    # Add Basics to the paramtype details dropdown
    $X_ParamType_Drp_Steps.Items.Add("Basics")
    $X_Params_Tree_View.items.add($Script:basics)
    }

# Create a Treeitem for each parameter and assign it to the tree view. Tag value is used for ordering.
$Script:Grid | foreach {
    $param = New-Object System.Windows.Controls.TreeViewItem
    $param.header = $_.header
    $param.name = $_.name
    $param.tag = $_.tag
    # Add parameter to Step "Basics"
    if ($Script:PackageType -eq 'Solution') { $Script:basics.items.add($param) }
    if ($Script:PackageType -eq 'Extension') { $X_Params_Tree_View.items.add($param) }
    }

$X_Params_Tree_View.items[0].IsSelected = $true

}

function F_Add_TreeItem {
Param(
[string]$step
)
#verify if a Treeitem with the same name already exists. If it does, show Tooltip with error. If not create the new treeitem.
if ($X_Params_Tree_View.Items.name -match $step.replace(' ','')){
    F_Validation -field 'X_Params_Tbx_AddStep' -field_value $X_Params_Tbx_AddStep.Text -nocondition -message 'Step already exists. Specify a different name.' -columnwidth 180
    }
else {
    # Indentify the current number of Steps
    $NumberofItems = $X_Params_Tree_View.items.Count
    # Get the last step. Counting starts at 0 so removing 1 from the $NumberOfItems
    $LastItem = ($X_Params_Tree_View.items | Sort-Object {$_.tag})[$NumberofItems -1]
    # Create a new treeitem
    $treeitem = New-Object System.Windows.Controls.TreeViewItem
    $treeitem.header = $step
    $treeitem.name = $step.replace(' ','')
    # Add tag with highest number + 1
    $treeitem.tag = ([int]$LastItem.tag +1)
    # Set Treeview item to expanded
    $treeitem.IsExpanded = $true
    # Add treeitem to treeview
    $X_Params_Tree_View.items.add($treeitem)
    # Add treeitem to ParamType dropdown
    $X_ParamType_Drp_Steps.Items.Add($step)
    }
}

function F_Remove_TreeItem {
Param(
[string]$step
)

# if the selected item is a step (by checking the tag of the parent item) AND if the selected item is not the "Basics" step AND if the selected item does not have any items.
if (($x_Params_Tree_View.SelectedItem.parent.tag -eq '@TreeViewRoot@') -and ($x_Params_Tree_View.SelectedItem.header -ne 'Basics') -and (!($x_Params_Tree_View.SelectedItem.HasItems))) { 
    # Remove the item from the treeview
    $X_Params_Tree_View.items.remove($x_Params_Tree_View.SelectedItem)
    # Remove the item from the Paramtype details dropdown
    $X_ParamType_Drp_Steps.Items.Remove($step)
    }
# if the selected item is a step (by checking the tag of the parent item) AND if the selected item is not the "Basics" step AND if the selected item has items itself.
elseif (($x_Params_Tree_View.SelectedItem.parent.tag -eq '@TreeViewRoot@') -and ($x_Params_Tree_View.SelectedItem.header -ne 'Basics') -and ($x_Params_Tree_View.SelectedItem.HasItems)) { 
    # Show validation messdage in the UI
    F_Validation -field 'X_Params_Tbx_RemoveStep' -nocondition -message 'You can only delete a step without params.' -columnwidth 180
    # TODO Is this step still required?
    $X_Params_Tbx_RemoveStep.Text = 'You can only delete a step without params.'
    }
# if the selected item is a step (by checking the tag of the parent item) AND if the selected item is the "Basics" step
elseif (($x_Params_Tree_View.SelectedItem.parent.tag -eq '@TreeViewRoot@') -and ($x_Params_Tree_View.SelectedItem.header -eq 'Basics') ) { 
    # Show Validation Message in the UI
    F_Validation -field 'X_Params_Tbx_RemoveStep' -nocondition -message 'The step basics cannot be removed.' -columnwidth 180
    }
}

function F_Move_TreeItem {
Param(
[string]$step
)

# if the selected item is a parameter (by checking the tag of the parent item) 
if ($x_Params_Tree_View.SelectedItem.parent.tag -ne '@TreeViewRoot@'){
    # Get the current treeitem
    $treeitem = $x_Params_Tree_View.SelectedItem
    # Get the current parent and remove the current item from it
    $OldParent = $treeitem.parent
    $OldParent.items.Remove($treeitem)
    # Get the new parent
    $NewParent = ($x_Params_Tree_View.Items | where {$_.header -eq $step})
    # Indentify the current number of parameters in the new step
    $NumberofItems = $NewParent.Items.Count
    # Get the last parameter in the new step. Counting starts at 0 so removing 1 from the $NumberOfItems
    # if there are no parameters in this step yet, set the tag of the current item to 0
    if ($NumberofItems -eq 0){
        $treeitem.tag = 0}
    # if there are exisitng parameters in this step, set the tag of the current item with tag of the last parameter of the new step + 1
    else { 
    $LastItem = ($NewParent.Items | Sort-Object {$_.tag})[$NumberofItems -1]
    $treeitem.tag = ([int]$LastItem.tag +1)
    }
    # Add current item to new step in treeview
    $NewParent.items.Add($treeitem)
    $treeitem.IsSelected = $true
    # Update the step value of the $Script:Grid item to match the current item
    ($Script:Grid | where {$_.name -eq $treeitem.name}).step = $NewParent.Header
    # Update the tag value of the $Script:Grid item to match the current item
    ($Script:Grid | where {$_.name -eq $treeitem.name}).tag = $treeitem.tag
    # Add the current item to the new step
    
    }
}

function F_Order_TreeItem {
Param (
[string]$Direction
)

# if the selected item is a parameter (by checking the tag of the parent item) 
if ($x_Params_Tree_View.SelectedItem.parent.tag -ne '@TreeViewRoot@'){

# Get the index number of the current selectItem from all items in the current step. Sorting by the tag value in each item. 
$AllItemsinStep = ($X_Params_Tree_View.SelectedItem.Parent.Items | sort-object {$_.tag}) 
$Index = $AllItemsinStep.IndexOf($X_Params_Tree_View.SelectedItem)

    If (($Direction -eq 'Up') -and ($Index -gt '0')){
        $NewPosition = ($Index -1)
        # Get Tag Values
        $TagCurrentValue = $X_Params_Tree_View.SelectedItem.tag
        $TagNewValue = $AllItemsinStep[$NewPosition].tag
        # Set Tag Values in treeview
        $AllItemsinStep[$NewPosition].tag = $TagCurrentValue
        $X_Params_Tree_View.SelectedItem.tag = $TagNewValue
        # Set tag value in $Script:Grid to match treeview
        ($Script:Grid | where {$_.name -eq $AllItemsinStep[$NewPosition].name}).tag = $TagCurrentValue
        ($Script:Grid | where {$_.name -eq $X_Params_Tree_View.SelectedItem.name}).tag = $TagNewValue
        }
    if (($Direction -eq 'Down') -and ($Index -lt ($AllItemsinStep.count -1))){
        $NewPosition = ($Index +1)
        # Get Tag Values
        $TagCurrentValue = $X_Params_Tree_View.SelectedItem.tag
        $TagNewValue = $AllItemsinStep[$NewPosition].tag
        # Set Tag Values
        $AllItemsinStep[$NewPosition].tag = $TagCurrentValue
        $X_Params_Tree_View.SelectedItem.tag = $TagNewValue
        # Update the tag value of the $Script:Grid item to match the current item
        ($Script:Grid | where {$_.name -eq $AllItemsinStep[$NewPosition].name}).tag = $TagCurrentValue
        ($Script:Grid | where {$_.name -eq $X_Params_Tree_View.SelectedItem.name}).tag = $TagNewValue
        }
}

# Create a new sort definition. Sorting by "Tag" ascending
$sortorder = New-Object System.ComponentModel.SortDescription("Tag","Ascending")
# Remove any existing sort definitions from the parent step item
$X_Params_Tree_View.SelectedItem.Parent.Items.SortDescriptions.Clear()
# Assign the new sort definition to the parent step item
$X_Params_Tree_View.SelectedItem.Parent.Items.SortDescriptions.Add($sortorder)
# Refresh the items with the new sort definition
$X_Params_Tree_View.SelectedItem.Parent.Items.Refresh()
}

function F_CreatePackage {
param (
[string]$path = [Environment]::GetFolderPath('MyDocuments')
)

#region manifest.json
$manifest_name = $X_Input_Tbx_Name.text.replace(' ','')
$manifest_publisher = $X_Input_Tbx_Publisher.text.replace(' ','')
$manifest_category = $X_Input_Tbx_category.text.split(';')
$manifest_version = "1.0.0"

$manifest = [pscustomobject]@{
    '$schema'="https://gallery.azure.com/schemas/2015-10-01/manifest.json#"
    "name"=$manifest_name
    "publisher"=$manifest_publisher
    "version"=$manifest_version
    "displayName"="ms-resource:displayName"
    "publisherDisplayName"="ms-resource:publisherDisplayName"
    "publisherLegalName"="ms-resource:publisherDisplayName"
    "summary"="ms-resource:summary"
    "longSummary"="ms-resource:longSummary"
    "description"="ms-resource:description"
    "longDescription"="ms-resource:description"
    "links"= @()
    "artifacts" = @(
        [PSCustomObject]@{
        "name"= "DefaultTemplate"
        "type"= "Template"
        "path" = "DeploymentTemplates\\mainTemplate.json"
        "isDefault"= $true
        }
        [PSCustomObject]@{
        "name"= "createUiDefinition"
        "type"= "Custom"
        "path" = "DeploymentTemplates\\createUiDefinition.json"
        "isDefault"= $false
        }
    )
    "images" = @(
        [PSCustomObject]@{
            "context"= "ibiza"
            "items" = @(
                [PSCustomObject]@{
                    "id"="small"
                    "path"= "icons\\Small.png"
                    "type"= "icon"
                    }
                [PSCustomObject]@{
                    "id"="medium"
                    "path"= "icons\\Medium.png"
                    "type"= "icon"
                    }
                [PSCustomObject]@{
                    "id"="large"
                    "path"= "icons\\Large.png"
                    "type"= "icon"
                    }
                [PSCustomObject]@{
                    "id"="wide"
                    "path"= "icons\\Wide.png"
                    "type"= "icon"
                    }
                [PSCustomObject]@{
                    "id"="screenShot0"
                    "path"= "Screenshots\\Screenshot.png"
                    "type"= "screenshot"
                    }
            )
        }
    )
    "categories"= $manifest_category
    "uiDefinition" = [PSCustomObject]@{
        "path"= "UIdefinition.json"
        }
}

if ($Script:PackageType -eq 'Extension'){
    $manifest.artifacts | where {$_.name -eq 'DefaultTemplate'} | foreach {$_.name = 'MainTemplate'}
    }

#endregion

#region UIDefinition.json
if ($Script:PackageType -eq 'Solution'){
    $UiDefinition_name="CreateMultiVmWizardBlade"
    $UiDefinition_extension="Microsoft_Azure_Compute"
    }
if ($Script:PackageType -eq 'Extension'){
    $UiDefinition_name="AddVmExtension"
    $UiDefinition_extension="Microsoft_Azure_Compute"
    }

$UiDefinition = [pscustomobject]@{
    '$schema'="https://gallery.azure.com/schemas/2015-02-12/UIDefinition.json#"
    "createDefinition" = [pscustomobject]@{
        "createBlade"=[pscustomobject]@{
            "name"= "$UiDefinition_name"
            "extension"= "$UiDefinition_extension"
        }
    }
}
#endregion

#region resources.resjson
$resources_displayname = $X_Input_Tbx_Name.text
$resources_publisher = $X_Input_Tbx_Publisher.text
$resources_summary = $X_Input_Tbx_Summary.text
$resources_longsummary = $X_Input_Tbx_Summary.text
$resources_description = $X_Input_Tbx_Description.text

$resources = [PSCustomObject]@{
  "displayName"= "$resources_displayname"
  "publisherDisplayName"= "$resources_publisher"
  "summary"= "$resources_summary"
  "longSummary"= "$resources_longsummary"
  "description"= "$resources_description"
  "documentationLink"= ""
}
#endregion

#region createUIDefinition
if ($Script:PackageType -eq 'Solution'){
    $createUIDefinition_handler='Microsoft.Compute.MultiVm'
    $createUIDefinition_version='0.1.0-preview'
    }
if ($Script:PackageType -eq 'Extension'){
    $createUIDefinition_handler='Microsoft.Compute.VmExtension'
    $createUIDefinition_version='1.0.0'
    }

$createUiDefinition = 
    [pscustomobject]@{
    "handler"= ""
    "version"= ""
    "parameters"= ""   
}

$createUiDefinition.handler = "$createUIDefinition_handler"
$createUiDefinition.version = "$createUIDefinition_version"
if ($Script:PackageType -eq 'Solution'){
    $createUiDefinition.parameters =  [pscustomobject]@{
            "basics" = ""; 
            "steps" = @(); 
            "outputs"= ""
            }  
    }
if ($Script:PackageType -eq 'Extension'){
        $createUiDefinition.parameters =  [pscustomobject]@{
            "elements" = ""; 
            "outputs"= ""
            }  
    }
#endregion

#region createUiDefinition steps (only for solution)
if ($Script:PackageType -eq 'Solution'){
    $uiDef_steps = @()
    $X_Params_Tree_View.items | where {$_.name -ne 'basics'} | foreach {
        $uiDef_step_name = $_.header
        $uiDef_step_name_trimmed = $_.name
        $uiDef_step = [pscustomobject]@{
            "name"="$uiDef_step_name_trimmed"
            "label"="$uiDef_step_name"
            "subLabel"= [pscustomobject]@{
                                "preValidation"="Configure the $uiDef_step_name settings"
                                "postValidation"="Done"
                                }
                "bladeTitle"= "$uiDef_step_name"
                "elements"= $null
            }
        $uiDef_steps += $uiDef_step 
        }
}
#endregion

#region createUiDefinition params
$uiDef_basics = @()
$uiDef_elements = @()
$uiDef_outputs = [ordered]@{}
if ($Script:PackageType -eq 'Extension'){
    $uiDef_outputs += @{"vmName"="[vmName()]"}
    $uiDef_outputs += @{"location"="[location()]"}
    }

$script:grid | Sort-Object step, tag | forEach {
    $uiDef_param_name = $_.name
    $uiDef_param_defaultValue = $_.defaultValue
    $uiDef_param_description = $_.description
    $uiDef_param_step = $_.step.replace(' ','')
    if ($_.uiType -eq 'Microsoft.Common.TextBox'){
    $uiDef_param = [pscustomobject]@{
        "name"= $uiDef_param_name
        "type"= "Microsoft.Common.TextBox"
        "label"= $uiDef_param_name
        "defaultValue"= $uiDef_param_defaultValue
        "toolTip"= $uiDef_param_description
    }
}
    if ($_.uiType -eq 'Microsoft.Common.DropDown'){
    $uiDef_param = [pscustomobject]@{
        "name"= $uiDef_param_name
        "type"= "Microsoft.Common.DropDown"
        "label"= $uiDef_param_name
        "defaultValue"= $uiDef_param_defaultValue
        "toolTip"= $uiDef_param_description
        "constraints"= [pscustomobject]@{
            "allowedValues"= @()
        }
    }
    $_.allowedValues | Foreach {
    $uiDef_param_allowedValues_label = $_.label
    $uiDef_param_allowedValues_value = $_.value
    $uiDef_param_allowedValues_single = [PSCustomObject]@{
        "label" = "$uiDef_param_allowedValues_label"
        "value" = "$uiDef_param_allowedValues_value"
        }
    $uiDef_param.constraints.allowedValues = $uiDef_param.constraints.allowedValues += $uiDef_param_allowedValues_single
    }
    
}
    if ($_.uiType -eq 'Microsoft.Common.PasswordBox'){
    $uiDef_param = [pscustomobject]@{
        "name"= $uiDef_param_name
        "type"= "Microsoft.Common.PasswordBox"
        "label"= [pscustomobject]@{
            "password"= "Password"
            "confirmPassword"= "Confirm password"
            }
        "toolTip"= $uiDef_param_description
        }
    }

if ($_.step -eq 'elements') { 
    # element
    $uiDef_elements += $uiDef_param 
    # output
    $uiDef_outputs += @{"$uiDef_param_name"="[$uiDef_param_step('$uiDef_param_name')]"}
    }
elseif ($_.step -eq 'basics') { 
    # element
    $uiDef_basics += $uiDef_param 
    # output
    $uiDef_outputs += @{"$uiDef_param_name"="[$uiDef_param_step('$uiDef_param_name')]"}
    }
else { 
    # element
    foreach($i in $uiDef_steps){
        if ($_.step.replace(' ','') -eq $i.name){ 
            [array]$i.elements += $uiDef_param 
            } 
        } 
    #output
    $uiDef_outputs += @{"$uiDef_param_name"="[steps('$uiDef_param_step').$uiDef_param_name]"}
    }
}

if ($Script:PackageType -eq 'Solution') {
    # basics
    if ($uiDef_basics.count -gt 0) {
        $createUiDefinition.parameters.basics = [PSCustomObject]@{}
        $createUiDefinition.parameters.basics = $uiDef_basics
        }
    # steps
    if ($uiDef_steps.count -gt 0) { 
        $createUiDefinition.parameters.steps = [PSCustomObject]@{}
        $createUiDefinition.parameters.steps = $uiDef_steps 
        }
    }
if ($Script:PackageType -eq 'Extension') {
   $createUiDefinition.parameters.elements = [PSCustomObject]@{}
   $createUiDefinition.parameters.elements = $uiDef_elements
   }
# outputs
$createUiDefinition.parameters.outputs = $uiDef_outputs
#endregion

#region Create Staging Folder 
$package_name = $X_Input_Tbx_Name.text.replace(' ','')
$package_publisher = $X_Input_Tbx_Publisher.text.replace(' ','')
$package_rootfolder = 'Marketplace'
$package_subfolder = ($package_rootfolder + '\' + $package_name + '_' + $package_publisher + '_' + (get-date).tostring("MM-dd-yyyy_HHmm"))
$package_path = ($path + '\' + $package_subfolder)

new-item -Path $path -Name $package_rootfolder -ItemType Directory -Force
new-item -Path $path -Name $package_subfolder -ItemType Directory
new-item -Path $path -Name ($package_subfolder + '\DeploymentTemplates') -ItemType Directory
new-item -Path $path -Name ($package_subfolder + '\Icons') -ItemType Directory
new-item -Path $path -Name ($package_subfolder + '\Strings') -ItemType Directory
new-item -Path $path -Name ($package_subfolder + '\Screenshots') -ItemType Directory
#endregion

#region create files
$manifest | convertto-json -Depth 20 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Out-File ($package_path + '\manifest.json')
$uiDefinition | convertto-json -Depth 20 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Out-File ($package_path + '\UIDefinition.json')
$resources | convertto-json -Depth 20 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Out-File ($package_path + '\Strings\resources.resjson')
$createUiDefinition | convertto-json -Depth 20 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Out-File ($package_path + '\DeploymentTemplates\createUiDefinition.json')

Copy-Item $X_Input_Tbx_Icon40.Text ($package_path + '\Icons\Small.png')
Copy-Item $X_Input_Tbx_Icon90.Text ($package_path + '\Icons\Medium.png')
Copy-Item $X_Input_Tbx_Icon115.Text ($package_path + '\Icons\Large.png')
Copy-Item $X_Input_Tbx_Icon255.Text ($package_path + '\Icons\Wide.png')
Copy-Item $X_Input_Tbx_Screenshot.Text ($package_path + '\Screenshots\Screenshot.png')

Copy-Item $X_Params_Tbx_Template.Text ($package_path + '\DeploymentTemplates\mainTemplate.json')
#endregion

#region create package
$createpackage_manifest = ($package_path + '\manifest.json')
$createpackage_output = ($path + '\' + $package_rootfolder)
$createpackage_azpkg = ($createpackage_output +'\' + $manifest_publisher + '.' + $manifest_name + '.' + $manifest_version + '.azpkg')

& $X_Params_Tbx_Exe.Text package -m $createpackage_manifest -o $createpackage_output

$X_Publish_Tbx_Package.text = $createpackage_azpkg
$X_Params_Tbx_PackagePath.text = $createpackage_azpkg
# remove-item $package_path -Recurse
#endregion
}

function F_PublishPackage {
$timer.Start()
$param_Endpoint = $X_Publish_Tbx_Endpoint.Text
$param_User = $X_Publish_Tbx_Username.Text
$param_Pass = $X_Publish_Pwb_Password1.Password
$param_ResourceGroup = 'system.staging'
$param_ResourceGroupLocation = 'local'
$param_StorageAccountName = 'artifacts'
$param_StorageContainerName = 'marketplace'
$param_Package = $X_Publish_Tbx_Package.Text
$job_publish_params = @(
    $param_Endpoint,
    $param_User,
    $param_Pass,
    $param_ResourceGroup,
    $param_ResourceGroupLocation,
    $param_StorageAccountName,
    $param_StorageContainerName
    $param_Package
    )
$Script:job = Start-Job -Name "PublishPackage" -ArgumentList $job_publish_params -ScriptBlock $job_publish
}
#endregion

#region Job
$job_publish = {
Param (
[string]$apiEndpoint = $args[0],
[string]$User = $args[1],
[string]$Pass = $args[2],
[string]$ResourceGroup = $args[3],
[string]$ResourceGroupLocation = $args[4],
[string]$StorageAccountName = $args[5],
[string]$StorageContainerName = $args[6],
[string]$Package = $args[7]
)

# log
Write-Output 'Verifying API endpoint'
# activity
try {
    $endpoint_test = Invoke-WebRequest https://$apiEndpoint/metadata/endpoints?api-version=1.0 -ErrorAction SilentlyContinue
    if ($endpoint_test.StatusCode -eq 200){
    Write-Output 'Api Endpoint is valid'
    }
    }
catch {
    Write-Output 'Unable to connect to Api Endpoint'
    Write-Output 'Publishing job cancelled'
    Exit
    }

# log
Write-Output 'Creating Credentials object'
# activity
$SecurePass = ConvertTo-SecureString $Pass -AsPlainText -Force
$AdminCreds = New-Object System.Management.Automation.PSCredential ($User, $SecurePass) 

# log
write-output 'Creating Environment'
# activity
$AdminAadID = $user.Split('@')[1]
$apiEndpointMetadata = Invoke-RestMethod -Uri https://$apiEndpoint/metadata/endpoints?api-version=1.0 -Method Get
$EnvAzureStackAdmin = Add-AzureRmEnvironment -Name 'AzureStackCloud' `
    -ActiveDirectoryEndpoint ($apiEndpointMetadata.authentication.loginEndpoint + $AdminAadID + '/') `
    -ActiveDirectoryServiceEndpointResourceId $apiEndpointMetadata.authentication.audiences[0] `
    -ResourceManagerEndpoint "https://$apiEndpoint/" `
    -GalleryEndpoint $apiEndpointMetadata.galleryEndpoint `
    -GraphEndpoint $apiEndpointMetadata.graphEndpoint 

# log
Write-Output 'Add account to environment'
# activity
$EnvAccountAzureStackAdmin = Add-AzureRmAccount -Environment $EnvAzureStackAdmin -Credential $AdminCreds
$rmProfile = Select-AzureRmProfile -Profile $EnvAccountAzureStackAdmin

# log
Write-Output 'Select default subscription'
# activity
$Subscription = Select-AzureRmSubscription -SubscriptionName 'Default Provider Subscription'

# condition
$Exists = Get-AzureRmResourceGroup -Name $ResourceGroup -Location $ResourceGroupLocation -ErrorAction SilentlyContinue  
If ($Exists){  
    # log
    Write-Output 'Using existing Resource Group' 
    }  
Else {  
    # log
    Write-Output 'Creating Resource Group'
    # activity
    New-AzureRmResourceGroup -Name $ResourceGroup -Location $ResourceGroupLocation  
    } 

# condition
$Exists = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue  
If ($Exists){  
    # log
    Write-Output 'Using existing Storage Account' 
}  
Else { 
    # log
    Write-Output 'Creating Storage Account'
    # activity 
    $StorageAccount = New-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroup -Type Standard_LRS -Location $ResourceGroupLocation  
    } 

# log
Write-Output 'Get Storage Account Key'

# activity
$StorageKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroup -Name $StorageAccountName

#log
Write-Output 'Create Storage Context'

#activity
$StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKeys.Key1 -Endpoint ($apiEndpoint.Substring($apiEndpoint.IndexOf(".") + 1))

#condition
$Exists = Get-AzureStorageContainer -Context $StorageContext -ErrorAction SilentlyContinue | where {$_.name -eq $StorageContainerName}
If ($Exists){  
    # log
    Write-Output 'Using existing Storage Container' 
    $StorageContainer = $Exists
}  
Else { 
    # log
    Write-Output 'Creating Storage Container'
    # activity 
    $StorageContainer = New-AzureStorageContainer -Name $StorageContainerName -Context $StorageContext -Permission Blob 
    }

# Log
Write-Output "Verify Publisher/Name/Version is unique"

# Activity
$tempfolder = new-item "$env:TEMP\azpkg" -ItemType Directory -Force
Copy-Item -Path $package -Destination ($tempfolder.FullName + '\package.zip')
Expand-Archive -Path ($tempfolder.FullName + '\package.zip') -DestinationPath $tempfolder.FullName
$manifest = Get-Content -Path ($tempfolder.FullName + '\manifest.json') | ConvertFrom-Json
Remove-item $tempfolder -Force -Recurse
$appName = ($manifest.publisher + '.' + $manifest.name + '.' + $manifest.version)

#condition
$Exists = Get-AzureRMGalleryItem -ErrorAction SilentlyContinue | where {$_.name -eq $appName}
if ($Exists) { 
    Write-Output "The Publisher/Name/Version already exists"
    Write-Output "Package not published"
    exit
    }
Else {
    # log
    Write-Output 'Upload package to storage container'
    # activity
    $blob = Set-AzureStorageBlobContent -Container $StorageContainerName -File $package -Context $StorageContext -Force
    #log
    Write-Output 'Publish package to Marketplace'
    #activity
    $publish = Add-AzureRMGalleryItem -GalleryItemUri ($blob.context.BlobEndPoint + $StorageContainerName + '/' + $blob.Name) -Verbose 
    }

if ($publish.StatusCode -eq '201'){ write-output 'Completed succesfully' }
else { write-output 'Publish item failed' }

}

#endregion

#region Events
#region Events Dashboard
$X_Dashboard_Btn_Solution.Add_Click({
$X_DashBoard.Visibility = 'Collapsed'
$X_Blade_Wizard.Visibility = 'Visible'
$X_Blade_Input.Visibility = 'Visible'
$X_Input_Stp_Category.Visibility = 'Visible'
$X_Params_Bdr_Create.Visibility = 'Collapsed'
$X_Params_Bdr_Continue.Visibility = 'Collapsed'
$X_Params_Stp_DeploymentWizard.Visibility = 'Collapsed'
$X_ParamType_Stp_AssignStep.Visibility = 'Visible'
F_Clear
F_Regex
$Script:PackageType = 'Solution'
})

$X_Dashboard_Btn_Extension.Add_Click({
$X_DashBoard.Visibility = 'Collapsed'
$X_Blade_Wizard.Visibility = 'Visible'
$X_Blade_Input.Visibility = 'Visible'
$X_Input_Stp_Category.Visibility = 'Visible'
$X_Params_Bdr_Create.Visibility = 'Collapsed'
$X_Params_Bdr_Continue.Visibility = 'Collapsed'
$X_Params_Stp_DeploymentWizard.Visibility = 'Collapsed'
$X_ParamType_Stp_AssignStep.Visibility = 'Collapsed'
F_Clear
F_Regex
$Script:PackageType = 'Extension'
})

$X_Dashboard_Btn_Publish.Add_Click({
$X_DashBoard.Visibility = 'Collapsed'
$X_Blade_Publish.Visibility = 'Visible'
F_Clear
F_Regex
})
#endregion

#region Events Blade Input
$X_Input_Btn_Preview.Add_Click({
$X_Blade_Preview.Visibility = 'Visible'
    F_Validation -field 'X_Input_Tbx_Name' -field_value $X_Input_Tbx_Name.Text -regex $X_Input_Tbx_Name.tag.regex -message $X_Input_Tbx_Name.tag.errormessage -columnwidth 258
    F_Validation -field 'X_Input_Tbx_Publisher' -field_value $X_Input_Tbx_Publisher.Text -regex $X_Input_Tbx_Publisher.tag.regex -message $X_Input_Tbx_Publisher.tag.errormessage-columnwidth 258
    F_Validation -field 'X_Input_Tbx_Summary' -field_value $X_Input_Tbx_Summary.Text -regex $X_Input_Tbx_Summary.tag.regex -message $X_Input_Tbx_Summary.tag.errormessage -columnwidth 258
    F_Validation -field 'X_Input_Tbx_Description' -field_value $X_Input_Tbx_Description.Text -regex $X_Input_Tbx_Description.tag.regex -message $X_Input_Tbx_Description.tag.errormessage -columnwidth 258
    F_Validation -field 'X_Input_Tbx_Category' -field_value $X_Input_Tbx_Category.Text -regex $X_Input_Tbx_Category.tag.regex -message $X_Input_Tbx_Category.tag.errormessage -columnwidth 258
    F_Validation -field 'X_Input_Tbx_Icon40' -field_value $X_Input_Tbx_Icon40.Text -extension '.png' -image @{width=40;height=40} -message $X_Input_Tbx_Icon40.tag.errormessage -columnwidth 190
    F_Validation -field 'X_Input_Tbx_Icon90' -field_value $X_Input_Tbx_Icon90.Text -extension '.png' -image @{width=90;height=90} -message $X_Input_Tbx_Icon90.tag.errormessage -columnwidth 190
    F_Validation -field 'X_Input_Tbx_Icon115' -field_value $X_Input_Tbx_Icon115.Text -extension '.png' -image @{width=115;height=115} -message $X_Input_Tbx_Icon115.tag.errormessage -columnwidth 190
    F_Validation -field 'X_Input_Tbx_Icon255' -field_value $X_Input_Tbx_Icon255.Text -extension '.png' -image @{width=255;height=115} -message $X_Input_Tbx_Icon255.tag.errormessage -columnwidth 190
    F_Validation -field 'X_Input_Tbx_Screenshot' -field_value $X_Input_Tbx_Screenshot.Text -extension '.png' -image @{width=533;height=324} -message $X_Input_Tbx_Screenshot.tag.errormessage -columnwidth 190
})

$X_Input_Btn_ParamFile.Add_Click({
F_Browse -title "Select Parameter File" -filter "PS1 (*.ps1)|*.ps1"
if ($Script:F_Browse_obj.FileName) { 
    $X_Input_Tbx_ParamFile.Text = $Script:F_Browse_obj.FileName
    F_Get_ParamFile -File $Script:F_Browse_obj.FileName
    F_Validation -field 'X_Input_Tbx_Name' -field_value $X_Input_Tbx_Name.Text -regex $X_Input_Tbx_Name.tag.regex -message $X_Input_Tbx_Name.tag.errormessage -columnwidth 258
    F_Validation -field 'X_Input_Tbx_Publisher' -field_value $X_Input_Tbx_Publisher.Text -regex $X_Input_Tbx_Publisher.tag.regex -message $X_Input_Tbx_Publisher.tag.errormessage-columnwidth 258
    F_Validation -field 'X_Input_Tbx_Summary' -field_value $X_Input_Tbx_Summary.Text -regex $X_Input_Tbx_Summary.tag.regex -message $X_Input_Tbx_Summary.tag.errormessage -columnwidth 258
    F_Validation -field 'X_Input_Tbx_Description' -field_value $X_Input_Tbx_Description.Text -regex $X_Input_Tbx_Description.tag.regex -message $X_Input_Tbx_Description.tag.errormessage -columnwidth 258
    F_Validation -field 'X_Input_Tbx_Category' -field_value $X_Input_Tbx_Category.Text -regex $X_Input_Tbx_Category.tag.regex -message $X_Input_Tbx_Category.tag.errormessage -columnwidth 258
    F_Validation -field 'X_Input_Tbx_Icon40' -field_value $X_Input_Tbx_Icon40.Text -extension '.png' -image @{width=40;height=40} -message $X_Input_Tbx_Icon40.tag.errormessage -columnwidth 190
    if ((!($script:validation_error)) -and ($X_Input_Tbx_Icon40.Text.Length -ne 0)) {
    $X_Preview_Img_Icon40.Source = $X_Input_Tbx_Icon40.Text
    }
    else {$X_Preview_Img_Icon40.Source = $null}
    F_Validation -field 'X_Input_Tbx_Icon90' -field_value $X_Input_Tbx_Icon90.Text -extension '.png' -image @{width=90;height=90} -message $X_Input_Tbx_Icon90.tag.errormessage -columnwidth 190
    F_Validation -field 'X_Input_Tbx_Icon115' -field_value $X_Input_Tbx_Icon115.Text -extension '.png' -image @{width=115;height=115} -message $X_Input_Tbx_Icon115.tag.errormessage -columnwidth 190
    F_Validation -field 'X_Input_Tbx_Icon255' -field_value $X_Input_Tbx_Icon255.Text -extension '.png' -image @{width=255;height=115} -message $X_Input_Tbx_Icon255.tag.errormessage -columnwidth 190
    F_Validation -field 'X_Input_Tbx_Screenshot' -field_value $X_Input_Tbx_Screenshot.Text -extension '.png' -image @{width=533;height=324} -message $X_Input_Tbx_Screenshot.tag.errormessage -columnwidth 190
    if ((!($script:validation_error)) -and ($X_Input_Tbx_Screenshot.Text.Length -ne 0)) {
    $X_Preview_Img_Screenshot.Source = $X_Input_Tbx_Screenshot.Text
    }
    else {$X_Preview_Img_Screenshot.Source = $null}
    }
})

$X_Input_Tbx_Name.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Name' `
    -field_value $X_Input_Tbx_Name.Text `
    -regex $X_Input_Tbx_Name.tag.regex `
    -message $X_Input_Tbx_Name.tag.errormessage `
    -columnwidth 258
})

$X_Input_Tbx_Name.Add_TextChanged({
$X_Preview_Tbl_Name.text = $X_Input_Tbx_Name.text
})

$X_Input_Tbx_Publisher.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Publisher' `
    -field_value $X_Input_Tbx_Publisher.Text `
    -regex $X_Input_Tbx_Publisher.tag.regex `
    -message $X_Input_Tbx_Publisher.tag.errormessage `
    -columnwidth 258
})

$X_Input_Tbx_Publisher.Add_TextChanged({
$X_Preview_Tbl_Publisher.text = $X_Input_Tbx_Publisher.text
$X_Preview_Tbl_Publisher2.text = $X_Input_Tbx_Publisher.text
})

$X_Input_Tbx_Summary.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Summary' `
    -field_value $X_Input_Tbx_Summary.Text `
    -regex $X_Input_Tbx_Summary.tag.regex `
    -message $X_Input_Tbx_Summary.tag.errormessage `
    -columnwidth 258
})

$X_Input_Tbx_Description.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Description' `
    -field_value $X_Input_Tbx_Description.Text `
    -regex $X_Input_Tbx_Description.tag.regex `
    -message $X_Input_Tbx_Description.tag.errormessage `
    -columnwidth 258
})

$X_Input_Tbx_Description.Add_TextChanged({
$X_Preview_Tbl_Description.text = $X_Input_Tbx_Description.text
})

$X_Input_Tbx_Category.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Category' `
    -field_value $X_Input_Tbx_Category.Text `
    -regex $X_Input_Tbx_Category.tag.regex `
    -message $X_Input_Tbx_Category.tag.errormessage `
    -columnwidth 258
})

$X_Input_Btn_Icon40.Add_Click({
F_Browse -title "Select Image" -filter "Image Files (*.png, *.jpg)| *.png;*.jpg"
if ($Script:F_Browse_obj.FileName) { 
    $X_Input_Tbx_Icon40.Text = $Script:F_Browse_obj.FileName
    F_Validation `
        -field 'X_Input_Tbx_Icon40' `
        -field_value $X_Input_Tbx_Icon40.Text `
        -extension '.png' `
        -image @{width=40;height=40} `
        -message $X_Input_Tbx_Icon40.tag.errormessage `
        -columnwidth 190
    }
if ((!($script:validation_error)) -and ($X_Input_Tbx_Icon40.Text.Length -ne 0)) {
    $X_Preview_Img_Icon40.Source = $X_Input_Tbx_Icon40.Text
    }
else {$X_Preview_Img_Icon40.Source = $null}
})

$X_Input_Tbx_Icon40.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Icon40' `
    -field_value $X_Input_Tbx_Icon40.Text `
    -extension '.png' `
    -image @{width=40;height=40} `
    -message $X_Input_Tbx_Icon40.tag.errormessage `
    -columnwidth 190
if ((!($script:validation_error)) -and ($X_Input_Tbx_Icon40.Text.Length -ne 0)) {
    $X_Preview_Img_Icon40.Source = $X_Input_Tbx_Icon40.Text
    }
else {$X_Preview_Img_Icon40.Source = $null}
})

$X_Input_Btn_Icon90.Add_Click({
F_Browse -title "Select Image" -filter "Image Files (*.png, *.jpg)| *.png;*.jpg"
if ($Script:F_Browse_obj.FileName) { 
    $X_Input_Tbx_Icon90.Text = $Script:F_Browse_obj.FileName
    F_Validation `
        -field 'X_Input_Tbx_Icon90' `
        -field_value $X_Input_Tbx_Icon90.Text `
        -extension '.png' `
        -image @{width=90;height=90} `
        -message $X_Input_Tbx_Icon90.tag.errormessage `
        -columnwidth 190
    }
})

$X_Input_Tbx_Icon90.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Icon90' `
    -field_value $X_Input_Tbx_Icon90.Text `
    -extension '.png' `
    -image @{width=90;height=90} `
    -message $X_Input_Tbx_Icon90.tag.errormessage `
    -columnwidth 190
})

$X_Input_Btn_Icon115.Add_Click({
F_Browse -title "Select Image" -filter "Image Files (*.png, *.jpg)| *.png;*.jpg"
if ($Script:F_Browse_obj.FileName) { 
    $X_Input_Tbx_Icon115.Text = $Script:F_Browse_obj.FileName
    F_Validation `
        -field 'X_Input_Tbx_Icon115' `
        -field_value $X_Input_Tbx_Icon115.Text `
        -extension '.png' `
        -image @{width=115;height=115} `
        -message $X_Input_Tbx_Icon115.tag.errormessage `
        -columnwidth 190
    }
})

$X_Input_Tbx_Icon115.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Icon115' `
    -field_value $X_Input_Tbx_Icon115.Text `
    -extension '.png' `
    -image @{width=115;height=115} `
    -message $X_Input_Tbx_Icon115.tag.errormessage `
    -columnwidth 190
})

$X_Input_Btn_Icon255.Add_Click({
F_Browse -title "Select Image" -filter "Image Files (*.png, *.jpg)| *.png;*.jpg"
if ($Script:F_Browse_obj.FileName) { 
    $X_Input_Tbx_Icon255.Text = $Script:F_Browse_obj.FileName
    F_Validation `
        -field 'X_Input_Tbx_Icon255' `
        -field_value $X_Input_Tbx_Icon255.Text `
        -extension '.png' `
        -image @{width=255;height=115} `
        -message $X_Input_Tbx_Icon255.tag.errormessage `
        -columnwidth 190
    }
})

$X_Input_Tbx_Icon255.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Icon255' `
    -field_value $X_Input_Tbx_Icon255.Text `
    -extension '.png' `
    -image @{width=255;height=115} `
    -message $X_Input_Tbx_Icon255.tag.errormessage `
    -columnwidth 190
})

$X_Input_Btn_Screenshot.Add_Click({
F_Browse -title "Select Image" -filter "Image Files (*.png, *.jpg)| *.png;*.jpg"
if ($Script:F_Browse_obj.FileName) { 
    $X_Input_Tbx_Screenshot.Text = $Script:F_Browse_obj.FileName
    F_Validation `
        -field 'X_Input_Tbx_Screenshot' `
        -field_value $X_Input_Tbx_Screenshot.Text `
        -extension '.png' `
        -image @{width=533;height=324} `
        -message $X_Input_Tbx_Screenshot.tag.errormessage `
        -columnwidth 190
    }
if ((!($script:validation_error)) -and ($X_Input_Tbx_Screenshot.Text.Length -ne 0)) {
    $X_Preview_Img_Screenshot.Source = $X_Input_Tbx_Screenshot.Text
    }
else {$X_Preview_Img_Screenshot.Source = $null}
})

$X_Input_Tbx_Screenshot.Add_LostFocus({
F_Validation `
    -field 'X_Input_Tbx_Screenshot' `
    -field_value $X_Input_Tbx_Screenshot.Text `
    -extension '.png' `
    -image @{width=533;height=324} `
    -message $X_Input_Tbx_Screenshot.tag.errormessage `
    -columnwidth 190
if ((!($script:validation_error)) -and ($X_Input_Tbx_Screenshot.Text.Length -ne 0)) {
    $X_Preview_Img_Screenshot.Source = $X_Input_Tbx_Screenshot.Text
    }
else {$X_Preview_Img_Screenshot.Source = $null}
})

$X_Input_Btn_OK.Add_Click({
F_Validation -field 'X_Input_Tbx_Name' -field_value $X_Input_Tbx_Name.Text -empty -regex $X_Input_Tbx_Name.tag.regex -message $X_Input_Tbx_Name.tag.errormessage -columnwidth 258
F_Validation -field 'X_Input_Tbx_Publisher' -field_value $X_Input_Tbx_Publisher.Text -empty -regex $X_Input_Tbx_Publisher.tag.regex -message $X_Input_Tbx_Publisher.tag.errormessage -columnwidth 258
F_Validation -field 'X_Input_Tbx_Summary' -field_value $X_Input_Tbx_Summary.Text -empty -regex $X_Input_Tbx_Summary.tag.regex -message $X_Input_Tbx_Summary.tag.errormessage -columnwidth 258
F_Validation -field 'X_Input_Tbx_Description' -field_value $X_Input_Tbx_Description.Text -empty -regex $X_Input_Tbx_Description.tag.regex -message $X_Input_Tbx_Description.tag.errormessage -columnwidth 258
F_Validation -field 'X_Input_Tbx_Category' -field_value $X_Input_Tbx_Category.Text -empty -regex $X_Input_Tbx_Category.tag.regex -message $X_Input_Tbx_Category.tag.errormessage -columnwidth 258
F_Validation -field 'X_Input_Tbx_Icon40' -field_value $X_Input_Tbx_Icon40.Text -empty -extension '.png' -image @{width=40;height=40} -message $X_Input_Tbx_Icon40.tag.errormessage -columnwidth 190
F_Validation -field 'X_Input_Tbx_Icon90' -field_value $X_Input_Tbx_Icon90.Text -empty -extension '.png' -image @{width=90;height=90} -message $X_Input_Tbx_Icon90.tag.errormessage -columnwidth 190
F_Validation -field 'X_Input_Tbx_Icon115' -field_value $X_Input_Tbx_Icon115.Text -empty -extension '.png' -image @{width=115;height=115} -message $X_Input_Tbx_Icon115.tag.errormessage -columnwidth 190
F_Validation -field 'X_Input_Tbx_Icon255' -field_value $X_Input_Tbx_Icon255.Text -empty -extension '.png' -image @{width=255;height=115} -message $X_Input_Tbx_Icon255.tag.errormessage -columnwidth 190
F_Validation -field 'X_Input_Tbx_Screenshot' -field_value $X_Input_Tbx_Screenshot.Text -empty -extension '.png' -image @{width=533;height=324} -message $X_Input_Tbx_Screenshot.tag.errormessage -columnwidth 190
$validation = (Get-Variable 'X_Input_Tbx*').value.parent.children | where {$_.GetType().fullname -eq 'System.Windows.Controls.Button' -and $_.Content -eq '!' -and $_.visibility -eq 'visible'}
if (!($validation)) {
    $X_Blade_Input.Visibility = 'Collapsed'
    $X_Blade_Preview.Visibility = 'Collapsed'
    $X_Blade_Params.Visibility = 'Visible'
    $X_Wizard_Btn_Input.Background = 'White'
    $X_Wizard_Btn_Parameters.Background = '#B3EBFB'
    }
})

$X_Input_Btn_Close.Add_Click({
$X_Blade_Wizard.Visibility = 'Collapsed'
$X_Blade_Input.Visibility = 'Collapsed'
$X_Blade_Preview.Visibility = 'Collapsed'
$X_DashBoard.Visibility = 'Visible'
F_Clear
F_Validation -field 'X_Input_Tbx_Name' -field_value $X_Input_Tbx_Name.Text -columnwidth 258
F_Validation -field 'X_Input_Tbx_Publisher' -field_value $X_Input_Tbx_Publisher.Text -columnwidth 258
F_Validation -field 'X_Input_Tbx_Summary' -field_value $X_Input_Tbx_Summary.Text -columnwidth 258
F_Validation -field 'X_Input_Tbx_Description' -field_value $X_Input_Tbx_Description.Text -columnwidth 258
F_Validation -field 'X_Input_Tbx_Category' -field_value $X_Input_Tbx_Category.Text -columnwidth 258
F_Validation -field 'X_Input_Tbx_Icon40' -field_value $X_Input_Tbx_Icon40.Text -columnwidth 190
F_Validation -field 'X_Input_Tbx_Icon90' -field_value $X_Input_Tbx_Icon90.Text -columnwidth 190
F_Validation -field 'X_Input_Tbx_Icon115' -field_value $X_Input_Tbx_Icon115.Text -columnwidth 190
F_Validation -field 'X_Input_Tbx_Icon255' -field_value $X_Input_Tbx_Icon255.Text -columnwidth 190
F_Validation -field 'X_Input_Tbx_Screenshot' -field_value $X_Input_Tbx_Screenshot.Text -columnwidth 190
})
#endregion

#region Events Blade Preview
$X_Preview_Btn_Close.Add_Click({
$X_Blade_Preview.Visibility = 'Collapsed'
})
#endregion

#region Events Blade Parameters
$X_Params_Btn_Template.Add_Click({
F_Browse -title "Select ARM Template" -filter "ARM Template (*.json)|*.json"
if ($Script:F_Browse_obj.FileName) {
    $X_Params_Tbx_Template.Text = $Script:F_Browse_obj.FileName
    $X_Params_Stp_DeploymentWizard.Visibility = 'Visible'
    $x_Params_Tree_View.items.Clear()
    $X_Blade_ParamType.Visibility = 'Collapsed'
    if ($Script:PackageType -eq 'Extension') {F_Validation -field 'X_Params_Tbx_Template' -field_value $X_Params_Tbx_Template.Text -extension '.json' -vmextension -columnwidth 190}
    else {F_Validation -field 'X_Params_Tbx_Template' -field_value $X_Params_Tbx_Template.Text -extension '.json' -columnwidth 190}
    if (!($script:validation_error)) {
        F_Create_Grid -File $X_Params_Tbx_Template.Text
        F_Create_Tree
        # Show Create button
        $X_Params_Bdr_Create.Visibility = 'Visible'
        # Show ParamType Blade
        $X_Blade_ParamType.Visibility = 'Visible'
        if ($Script:PackageType -eq 'solution'){$X_Params_Bdr_Steps.Visibility = 'Visible'}
        }
    }
})

$x_Params_Tree_View.Add_SelectedItemChanged({
F_Validation -field 'X_Params_Tbx_RemoveStep' -field_value $X_Params_Tbx_RemoveStep.Text -columnwidth 180
# if the selected item is a parameter (by checking the tag of the parent item) 
if ($x_Params_Tree_View.SelectedItem.parent.tag -ne '@TreeViewRoot@'){
    # Show Parameter Properties Panel
    $X_ParamType_Stp_Param.Visibility ='Visible'
    # Hide Step Properties Panel
    $X_ParamType_Stp_Step.Visibility = 'Collapsed'
    # Get $Script:Grid item that matched the selected treeviewitem
    $GridSelectedItem = ($Script:Grid | where {$_.name -eq $x_Params_Tree_View.SelectedItem.name})
    # Set Parameter properties in ParamType fields
    $X_ParamType_Drp_Steps.text = $GridSelectedItem.step
    $X_ParamType_Tbl_ParamName.text = $GridSelectedItem.Header
    $X_ParamType_Tbl_ParamType.text = $GridSelectedItem.type
    $X_ParamType_Tbl_uiType.text = $GridSelectedItem.uiType
    }
# if the selected item is a step (by checking the tag of the parent item) 
if ($x_Params_Tree_View.SelectedItem.parent.tag -eq '@TreeViewRoot@'){
    # Show ParamType Blade
    $X_Blade_ParamType.Visibility = 'Visible'
    # Show Step Properties Panel
    $X_ParamType_Stp_Step.Visibility = 'Visible'
    # Hide Parameter Properties Panel
    $X_ParamType_Stp_Param.Visibility ='Collapsed'
    # Set Step properties in ParamType fields
    $X_ParamType_Tbl_Step_Label.text = $x_Params_Tree_View.SelectedItem.Header
    $X_ParamType_Tbl_Step_Name.text = $x_Params_Tree_View.SelectedItem.Name
    }
})

$X_Params_Btn_AddStep.Add_Click({
F_Validation -field 'X_Params_Tbx_AddStep' -field_value $X_Params_Tbx_AddStep.Text -regex $X_Params_Tbx_AddStep.tag.regex -message $X_Params_Tbx_AddStep.tag.errormessage -columnwidth 180

$validation = $X_Params_Tbx_AddStep.parent.children | where {$_.GetType().fullname -eq 'System.Windows.Controls.Button' -and $_.Content -eq '!' -and $_.visibility -eq 'visible'}
if(!($validation)){     
    F_Add_TreeItem -step $X_Params_Tbx_AddStep.Text 
    $X_Params_Tbx_AddStep.Text = $null
    }
})

$X_Params_Btn_RemoveStep.Add_Click({
F_Remove_TreeItem $X_Params_Tree_View.SelectedItem.Header
})

$X_ParamType_Drp_Steps.Add_DropDownClosed({
F_Move_TreeItem $X_ParamType_Drp_Steps.Text
})

$X_ParamType_Btn_MoveUp.Add_Click({
F_Order_TreeItem -Direction Up
})

$X_ParamType_Btn_MoveDown.Add_Click({
F_Order_TreeItem -Direction Down
})

$X_Params_Btn_Exe.Add_Click({
F_Browse -title "Select ARM Template" -filter "AzureGalleryPackager (*.exe)|*.exe"
if ($Script:F_Browse_obj.FileName) {
    $X_Params_Tbx_Exe.Text = $Script:F_Browse_obj.FileName
    F_Validation -field 'X_Params_Tbx_Exe' -field_value $X_Params_Tbx_Exe.Text -extension '.exe' -columnwidth 190
    }
})

$X_Params_Tbx_Exe.Add_LostFocus({
F_Validation `
    -field 'X_Params_Tbx_Exe' `
    -field_value $X_Params_Tbx_Exe.Text `
    -extension '.exe' `
    -columnwidth 190
})

$X_Params_Btn_Create.Add_Click({
F_Validation -field 'X_Params_Tbx_Template' -field_value $X_Params_Tbx_Template.Text -empty -extension '.json' -columnwidth 190
F_Validation -field 'X_Params_Tbx_Exe' -field_value $X_Params_Tbx_Exe.Text -empty -extension '.exe' -columnwidth 190
$validation = (Get-Variable 'X_Params_Tbx*').value.parent.children | where {$_.GetType().fullname -eq 'System.Windows.Controls.Button' -and $_.Content -eq '!' -and $_.visibility -eq 'visible'}
if (!($validation)) {
    F_CreatePackage
    $X_Params_Bdr_Continue.Visibility = 'Visible'
    $X_Params_Bdr_Create.Visibility = 'Collapsed'
    }
})

$X_Params_Btn_PathCopy.Add_Click({
$X_Params_Tbx_PackagePath.text | clip
})

$X_Params_Btn_Publish.Add_Click({
    $X_Blade_Params.Visibility = 'Collapsed'
    $X_Blade_ParamType.Visibility = 'Collapsed'
    $X_Blade_Publish.Visibility = 'Visible'
    $X_Wizard_Btn_Parameters.Background = 'White'
    $X_Wizard_Btn_Publish.Background = '#B3EBFB'
})

$X_Params_Btn_Stop.Add_Click({
$X_Blade_Wizard.Visibility = 'Collapsed'
$X_Blade_Params.Visibility = 'Collapsed'
$X_Blade_ParamType.Visibility = 'Collapsed'
$X_DashBoard.Visibility = 'Visible'
})

$X_Params_Btn_Close.Add_Click({
$X_Blade_Wizard.Visibility = 'Collapsed'
$X_Blade_Params.Visibility = 'Collapsed'
$X_Blade_ParamType.Visibility = 'Collapsed'
$X_DashBoard.Visibility = 'Visible'
})
#endregion

#region Events Blade Publish
$X_Publish_Btn_Package.Add_Click({
F_Browse -title "Select Marketplace item package file" -filter "Marketplace Item Package (*.azpkg)|*.azpkg"

if ($Script:F_Browse_obj.FileName) { 
    $X_Publish_Tbx_Package.Text = $Script:F_Browse_obj.FileName
    F_Validation -field 'X_Publish_Tbx_Package' -field_value $X_Publish_Tbx_Package.Text -extension '.azpkg' -columnwidth 190
    }
})

$X_Publish_Tbx_Package.Add_LostFocus({
F_Validation -field 'X_Publish_Tbx_Package' -field_value $X_Publish_Tbx_Package.Text -extension '.azpkg' -columnwidth 190
})

$X_Publish_Pwb_Password1.Add_LostFocus({
if ($X_Publish_Pwb_Password2.Password -ne ''){
    F_Validation -field 'X_Publish_Pwb_Password1' -field_value $X_Publish_Pwb_Password1.Password -compare $X_Publish_Pwb_Password2.Password -columnwidth 258 
    }
})

$X_Publish_Pwb_Password2.Add_LostFocus({
if ($X_Publish_Pwb_Password1.Password -ne ''){
    F_Validation -field 'X_Publish_Pwb_Password2' -field_value $X_Publish_Pwb_Password2.Password -compare $X_Publish_Pwb_Password1.Password -columnwidth 258 
    }
})

$X_Publish_Btn_Publish.Add_Click({
F_Validation -field 'X_Publish_Tbx_Package' -field_value $X_Publish_Tbx_Package.Text -empty -extension '.azpkg' -columnwidth 190
F_Validation -field 'X_Publish_Tbx_Username' -field_value $X_Publish_Tbx_Username.Text -empty -columnwidth 258
F_Validation -field 'X_Publish_Pwb_Password1' -field_value $X_Publish_Pwb_Password1.Password -empty -compare $X_Publish_Pwb_Password2.Password -columnwidth 258
F_Validation -field 'X_Publish_Pwb_Password2' -field_value $X_Publish_Pwb_Password2.Password -empty -compare $X_Publish_Pwb_Password1.Password -columnwidth 258
F_Validation -field 'X_Publish_Tbx_Endpoint' -field_value $X_Publish_Tbx_Endpoint.Text -empty -columnwidth 258
$validation = (Get-Variable | where {($_.name -match 'X_Publish_Tbx') -or ($_.name -match 'X_Publish_Pwb')}).value.parent.children | where {$_.GetType().fullname -eq 'System.Windows.Controls.Button' -and $_.Content -eq '!' -and $_.visibility -eq 'visible'}
if ((!($validation)) -and ($Script:job.state -ne 'running')){
    $X_Publish_Lsv_Log.Items.Clear()
    $X_Publish_Lsv_Log.Items.Add("Starting publishing job") 
    F_PublishPackage }
})

$timer.Add_Tick({
    if ($Script:job.state -eq 'running') {
        [array]$result = receive-job $Script:job
        if ($result.count -ne '0') {
            $result | foreach { 
                $X_Publish_Lsv_Log.Items.Add("$_")
                $Script:loglast = $_
            }
         }
         else {
            if ($Script:loglast.length -gt 0){
                $X_Publish_Lsv_Log.Items.Remove("$Script:loglast")
                $Script:loglast = ($Script:loglast + '.')
                $X_Publish_Lsv_Log.Items.Add("$Script:loglast")
                }
            }
        }
    elseif ($Script:job.state -eq 'completed') { 
        $timer.Stop() 
        $result = receive-job $Script:job
        $result | foreach { $X_Publish_Lsv_Log.Items.Add("$_") }
        $X_Publish_Lsv_Log.Items.Add("Job finished")
        }
    elseif ($Script:job.state -eq 'failed') {
        $timer.Stop()
        $result = receive-job $Script:job
        $result | foreach { $X_Publish_Lsv_Log.Items.Add("$_") }
        $X_Publish_Lsv_Log.Items.Add("Job Failed")
        }
    else { $timer.Stop() } 
    })

$X_Publish_Btn_Close.Add_Click({
$X_Blade_Wizard.Visibility = 'Collapsed'
$X_Blade_Publish.Visibility = 'Collapsed'
$X_Dashboard.Visibility = 'Visible'
$X_Wizard_Btn_Publish.Background = 'White'
$X_Wizard_Btn_Input.Background = '#B3EBFB'
F_Validation -field 'X_Publish_Tbx_Package' -field_value $X_Publish_Tbx_Package.Text -columnwidth 190
F_Validation -field 'X_Publish_Tbx_Username' -field_value $X_Publish_Tbx_Username.Text -columnwidth 258
F_Validation -field 'X_Publish_Pwb_Password1' -field_value $X_Publish_Pwb_Password1.Password -columnwidth 258
F_Validation -field 'X_Publish_Pwb_Password2' -field_value $X_Publish_Pwb_Password2.Password  -columnwidth 258
F_Validation -field 'X_Publish_Tbx_Endpoint' -field_value $X_Publish_Tbx_Endpoint.Text -columnwidth 258
if ($script:job.id){ remove-job $script:job.id -ErrorAction SilentlyContinue }
})
#endregion

#endregion Events

$Form.ShowDialog() | out-null

