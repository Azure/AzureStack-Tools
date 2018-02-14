<#
.SYNOPSIS
Short description
This installer UI simplifies the preperation and deployment of the Azure Stack Development Kit

.DESCRIPTION
The Azure Stack Development Kit installer UI provides a UI with the following features

- Prepare the SafeOS for deployment
- Prepare the Azure Stack Development Kit Installation
- Rerun and Gather Logs
- Reboot to SafeOS

.EXAMPLE
.\asdk-installer.ps1

.NOTES
To install the Azure Stack Development Kit you require

- A physical server that meets the requirements
- The latest cloudbuilder.vhdx
- The installer UI script

The Azure Stack Development Kit installer UI script is based on PowerShell and the Windows Presentation Foundation. It is published in this public repository so you can make improvements to it by submitting a pull request.
#>

#requires –runasadministrator

#region Text
$Text_Generic = @{}
$Text_Generic.Version = "1.0.06"
$Text_Generic.Password_NotMatch = "Passwords do not match"
$Text_Generic.Regex_Fqdn = "<yourtenant.onmicrosoft.com> can only contain A-Z, a-z, 0-9, dots and a hyphen"
$Text_Generic.Regex_Computername = "Computername must be 15 characters or less and can only contain A-Z, a-z, 0-9 and a hyphen"
$Text_Generic.Regex_IpAddress = "Ip Address must be specified in the x.x.x.x format"
$Text_Generic.Regex_IpAddressCidr = "Ip Address must be specified in the x.x.x.x/x format"
$Text_Generic.Regex_LocalAdmin = "The specified password does not match the current local administrator password"

$Text_SafeOS = @{}
$Text_SafeOS.Mode_Title = "Prepare for Deployment"
$Text_SafeOS.Mode_LeftTitle = "Prepare Environment"
$Text_SafeOS.Mode_LeftContent = "Prepare the Cloudbuilder vhdx"
$Text_SafeOS.Mode_RightTitle = "Online documentation"
$Text_SafeOS.Mode_RightContent = "Read the online documentation."
$Text_SafeOS.Prepare_Title = "Select Cloudbuilder vhdx"
$Text_SafeOS.Prepare_VHDX_IsMounted = "This vhdx is already mounted"
$Text_SafeOS.Prepare_VHDX_InvalidPath = "Not a valid Path"
$Text_SafeOS.Prepare_Drivers_InvalidPath = "Not a valid Path"
$Text_SafeOS.Unattend_Title = "Optional settings"
$Text_SafeOS.NetInterface_Title = "Select Network Interface for the Azure Stack host"
$Text_SafeOS.NetInterface_Warning = "Select the network interface that will be configured for the host of the Azure Stack Development Kit. Ensure you have network connectivity to the selected network adapter before proceeding."
$Text_SafeOS.NetConfig_Title = "Azure Stack host IP configuration"
$Text_SafeOS.Job_Title = "Preparing the environment"
$Text_SafeOS.Summary_Content = "The cloudbuilder vhdx is prepared succesfully. Please reboot. The server will boot from the CloudBuilder VHD and you can start the installation after signing in as the administrator."
$Text_SafeOS.Mode_RightLink = "https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-run-powershell-script"

$Text_Install = @{}
$Text_Install.Mode_Title = "Installation"
$Text_Install.Mode_LeftTitle = "Install"
$Text_Install.Mode_LeftContent = "Install the Microsoft Azure Stack Development Kit"
$Text_Install.Mode_RightTitle = "Reboot"
$Text_Install.Mode_RightContent = "Select the Operating System to override the default boot order for this reboot."
$Text_Install.Reboot_Title = "Reboot"
$Text_Install.NetInterface_Title = "Select Network Interface for the Azure Stack host"
$Text_Install.NetInterface_Warning = "Only one adapter can be used for the Azure Stack Development Kit host. Select the adapter used for the deployment. All other adapters will be disabled by the installer. Ensure you have network connectivity to the selected network adapter before proceeding."
$Text_Install.NetConfig_Title = "Network Configuration for BGPNAT01"
$Text_Install.Credentials_Title = "Specify Identity Provider and Credentials"
$Text_Install.Summary_Title = "Summary"
$Text_Install.Summary_Content = "The following script will be used for deploying the Development Kit"
$Text_Install.Summary_Warning = "You will be prompted for your Azure AD credentials 2-3 minutes after the installation starts"
$Text_Install.Job_Title = "Verifying network interface card properties"

$Text_Rerun = @{}
$Text_Rerun.Mode_Title = "Rerun Installation"
$Text_Rerun.Mode_LeftTitle = "Rerun Installation"
$Text_Rerun.Mode_LeftContent = "Rerun the current Microsoft Azure Stack Developement Kit deployment from where it failed"
$Text_Rerun.Mode_Title_Logs = "Gather Logs"
$Text_Rerun.Mode_LeftTitle_Logs = "Gather Logs"
$Text_Rerun.Mode_LeftContent_Logs = "Gather the Azure Stack deployment log files"
$Text_Rerun.Summary_Title = "Rerun"
$Text_Rerun.Summary_Content = "Click Rerun to resume the current Microsoft Azure Stack Developement Kit deployment from where it failed"
$Text_Rerun.Summary_Title_Logs = "Gather Logs"
$Text_Rerun.Summary_Content_Logs = "Gather the Azure Stack log files and save to c:\AzureStackLogs"

$Text_Completed = @{}
$Text_Completed.Mode_Title = "Installation completed"
$Text_Completed.Mode_LeftTitle = "Gather Logs"
$Text_Completed.Mode_LeftContent = "Gather the Azure Stack deployment log files"
$Text_Completed.Summary_Title = "Gather Logs"
$Text_Completed.Summary_Content = "Gather the Azure Stack log files and save to c:\AzureStackLogs"
#endregion Text

#region XAML
$Xaml = @'
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="Microsoft Azure Stack Development Kit" Height="650" Width="664" Background="#2D2D2F" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <!--#region Textbox -->
        <Style x:Key="{x:Type TextBox}" TargetType="{x:Type TextBoxBase}">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="KeyboardNavigation.TabNavigation" Value="None"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="Foreground" Value="#EBEBEB"/>
            <Setter Property="MinWidth" Value="120"/>
            <Setter Property="MinHeight" Value="23.5"/>
            <Setter Property="AllowDrop" Value="true"/>
            <Setter Property="ToolTipService.InitialShowDelay" Value="0"/>
            <Setter Property="CaretBrush" Value="#EBEBEB"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type TextBoxBase}">
                        <Border Name="Border" Padding="2,0,2,0" Background="#343447" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" >
                            <ScrollViewer Margin="0" x:Name="PART_ContentHost"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Border" Property="Background" Value="#343447"/>
                                <Setter TargetName="Border" Property="BorderBrush" Value="Transparent"/>
                                <Setter Property="Foreground" Value="#A0A0A0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!--#endregion Textbox -->
        <!--#region Checkbox -->
        <Style x:Key="CheckBoxFocusVisual">
            <Setter Property="Control.Template">
                <Setter.Value>
                    <ControlTemplate>
                        <Border>
                            <Rectangle Margin="15,0,0,0" StrokeThickness="1" Stroke="#60000000" StrokeDashArray="1 2"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="{x:Type CheckBox}" TargetType="CheckBox">
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="Foreground" Value="#EBEBEB"/>
            <Setter Property="FocusVisualStyle"	Value="{StaticResource CheckBoxFocusVisual}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <BulletDecorator Background="Transparent">
                            <BulletDecorator.Bullet>
                                <Border x:Name="Border" Width="15" Height="15" Background="#343447" BorderThickness="1" BorderBrush="#ABADB3">
                                    <Rectangle x:Name="CheckMark" Fill="#EBEBEB" Width="7" Height="7"/>
                                </Border>
                            </BulletDecorator.Bullet>
                            <ContentPresenter Margin="10,0,0,0" VerticalAlignment="Center" HorizontalAlignment="Left" RecognizesAccessKey="True"/>
                        </BulletDecorator>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="false">
                                <Setter TargetName="CheckMark" Property="Visibility" Value="Collapsed"/>
                            </Trigger>

                            <Trigger Property="IsEnabled" Value="false">
                                <Setter TargetName="Border" Property="Background" Value="#343447" />
                                <Setter TargetName="Border" Property="BorderBrush" Value="Transparent" />
                                <Setter Property="Foreground" Value="#EBEBEB"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!--#endregion Checkbox -->
        <!--#region Passwordbox -->
        <Style x:Key="{x:Type PasswordBox}" TargetType="{x:Type PasswordBox}">
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="KeyboardNavigation.TabNavigation" Value="None"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="Foreground" Value="#EBEBEB"/>
            <Setter Property="PasswordChar" Value="●"/>
            <Setter Property="MinWidth" Value="120"/>
            <Setter Property="MinHeight" Value="23.5"/>
            <Setter Property="AllowDrop" Value="true"/>
            <Setter Property="CaretBrush" Value="#EBEBEB"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type PasswordBox}">
                        <Border Name="Border" Padding="2,0,2,0" Background="#343447" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" >
                            <ScrollViewer x:Name="PART_ContentHost" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Border" Property="Background" Value="#343447"/>
                                <Setter TargetName="Border" Property="BorderBrush" Value="Transparent"/>
                                <Setter Property="Foreground" Value="#A0A0A0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!--#endregion Passwordbox -->
        <!--#region Combobox -->
        <!--Combobox -->
        <ControlTemplate x:Key="ComboBoxToggleButton" TargetType="ToggleButton">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition />
                    <ColumnDefinition Width="20" />
                </Grid.ColumnDefinitions>
                <!--ToggleButton OuterBorder and Dropdownbutton Block No Event -->
                <Border x:Name="Border" Grid.ColumnSpan="2" Background="#343447" BorderBrush="#ABADB3" BorderThickness="1" />
                <!--ToggleButton InnerTextbox No Event -->
                <Border Grid.Column="0" Margin="1" Background="#343447" BorderBrush="Green" BorderThickness="0" />
                <!--ToggleButton DropdownButton No Event -->
                <Path x:Name="Arrow" Grid.Column="1" Fill="#EBEBEB" HorizontalAlignment="Center" VerticalAlignment="Center" Data="M 0 0 L 4 4 L 8 0 Z"/>
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property="IsEnabled" Value="True">
                    <Setter Property="Foreground" Value="#EBEBEB"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>
        <ControlTemplate x:Key="ComboBoxTextBox" TargetType="TextBox">
            <Border x:Name="PART_ContentHost" Focusable="False"/>
        </ControlTemplate>
        <Style x:Key="{x:Type ComboBox}" TargetType="ComboBox">
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.CanContentScroll" Value="true"/>
            <Setter Property="MinWidth" Value="120"/>
            <Setter Property="MinHeight" Value="23.5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton Name="ToggleButton" Template="{StaticResource ComboBoxToggleButton}" Grid.Column="2" Focusable="false" IsChecked="{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press">
                            </ToggleButton>
                            <ContentPresenter Name="ContentSite" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" Margin="5,3,23,3" VerticalAlignment="Center" HorizontalAlignment="Left" />
                            <TextBox x:Name="PART_EditableTextBox" Style="{x:Null}" Template="{StaticResource ComboBoxTextBox}" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="3,3,23,3" Focusable="True" Background="Transparent" Visibility="Hidden" IsReadOnly="{TemplateBinding IsReadOnly}"/>
                            <Popup Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Grid Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <!--Combobox Item Background No Event -->
                                    <Border x:Name="DropDownBorder" Background="#343447" BorderThickness="1" BorderBrush="#ABADB3"/>
                                    <ScrollViewer SnapsToDevicePixels="True">
                                        <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained" />
                                    </ScrollViewer>
                                </Grid>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="HasItems" Value="false">
                                <Setter TargetName="DropDownBorder" Property="MinHeight" Value="95"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter Property="Foreground" Value="Green"/>
                            </Trigger>
                            <Trigger Property="IsGrouping" Value="true">
                                <Setter Property="ScrollViewer.CanContentScroll" Value="false"/>
                            </Trigger>
                            <Trigger Property="IsEditable" Value="true">
                                <Setter Property="IsTabStop" Value="false"/>
                                <Setter TargetName="PART_EditableTextBox" Property="Visibility"	Value="Visible"/>
                                <Setter TargetName="ContentSite" Property="Visibility" Value="Hidden"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
            </Style.Triggers>
        </Style>
        <!-- ComboboxItem -->
        <Style x:Key="{x:Type ComboBoxItem}" TargetType="ComboBoxItem">
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border Name="Border" Padding="5,3,5,3" SnapsToDevicePixels="true">
                            <ContentPresenter />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="true">
                                <!-- ComboboxItem Hover -->
                                <Setter TargetName="Border" Property="Background" Value="#4590CE"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="True">
                                <!-- ComboboxItem Text -->
                                <Setter Property="Foreground" Value="#EBEBEB"/>
                                <Setter Property="FontFamily" Value="Segoe UI"/>
                                <Setter Property="FontSize" Value="14"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!--#endregion Combobox -->
        <!--#region Button -->
        <Style x:Key="ButtonFocusVisual">
            <Setter Property="Control.Template">
                <Setter.Value>
                    <ControlTemplate>
                        <Border>
                            <Rectangle Margin="2" StrokeThickness="1" Stroke="#60000000" StrokeDashArray="1 2"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button">
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="FocusVisualStyle" Value="{StaticResource ButtonFocusVisual}"/>
            <Setter Property="MinHeight" Value="23.5"/>
            <Setter Property="MinWidth" Value="75"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Foreground" Value="#EBEBEB"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <!-- Background and Border No Event -->
                        <Border x:Name="Border" BorderThickness="1" Background="#202020" BorderBrush="#ABADB3">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalAlignment}" VerticalAlignment="{TemplateBinding VerticalAlignment}" RecognizesAccessKey="True"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsKeyboardFocused" Value="true">
                                <Setter TargetName="Border" Property="BorderBrush" Value="#ABADB3" />
                            </Trigger>
                            <Trigger Property="IsDefaulted" Value="true">
                                <Setter TargetName="Border" Property="BorderBrush" Value="#ABADB3" />
                            </Trigger>
                            <!-- Button Hover -->
                            <Trigger Property="IsMouseOver" Value="true">
                                <Setter TargetName="Border" Property="Background" Value="#4590CE" />
                                <Setter TargetName="Border" Property="BorderBrush" Value="#4590CE" />
                                <Setter TargetName="Border" Property="Cursor" Value="Hand" />
                            </Trigger>
                            <!-- Button Pressed -->
                            <Trigger Property="IsPressed" Value="true">
                                <Setter TargetName="Border" Property="Background" Value="#4590CE" />
                                <Setter TargetName="Border" Property="BorderBrush" Value="#4590CE" />
                            </Trigger>
                            <!-- Button IsEnabled false -->
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter TargetName="Border" Property="Background" Value="#202020" />
                                <Setter TargetName="Border" Property="BorderBrush" Value="#555555" />
                                <Setter Property="Foreground" Value="#555555"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!--#endregion Button -->
        <!--#region Listview -->
        <!--Listview -->
        <Style x:Key="{x:Static GridView.GridViewScrollViewerStyleKey}" TargetType="ScrollViewer">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollViewer">
                        <Grid Background="{TemplateBinding Background}">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <DockPanel Margin="{TemplateBinding Padding}">
                                <ScrollViewer DockPanel.Dock="Top" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Hidden" Focusable="false">
                                    <GridViewHeaderRowPresenter Margin="0" Columns="{Binding Path=TemplatedParent.View.Columns,RelativeSource={RelativeSource TemplatedParent}}" ColumnHeaderContainerStyle="{Binding Path=TemplatedParent.View.ColumnHeaderContainerStyle, RelativeSource={RelativeSource TemplatedParent}}" ColumnHeaderTemplate="{Binding Path=TemplatedParent.View.ColumnHeaderTemplate, RelativeSource={RelativeSource TemplatedParent}}" ColumnHeaderTemplateSelector="{Binding Path=TemplatedParent.View.ColumnHeaderTemplateSelector, RelativeSource={RelativeSource TemplatedParent}}" AllowsColumnReorder="{Binding Path=TemplatedParent.View.AllowsColumnReorder, RelativeSource={RelativeSource TemplatedParent}}" ColumnHeaderContextMenu="{Binding Path=TemplatedParent.View.ColumnHeaderContextMenu, RelativeSource={RelativeSource TemplatedParent}}" ColumnHeaderToolTip="{Binding Path=TemplatedParent.View.ColumnHeaderToolTip, RelativeSource={RelativeSource TemplatedParent}}" SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
                                </ScrollViewer>
                                <ScrollContentPresenter Name="PART_ScrollContentPresenter" KeyboardNavigation.DirectionalNavigation="Local" CanContentScroll="True" CanHorizontallyScroll="False" CanVerticallyScroll="False"/>
                            </DockPanel>
                            <ScrollBar Name="PART_HorizontalScrollBar" Orientation="Horizontal" Grid.Row="1" Maximum="{TemplateBinding ScrollableWidth}" ViewportSize="{TemplateBinding ViewportWidth}" Value="{TemplateBinding HorizontalOffset}" Visibility="{TemplateBinding ComputedHorizontalScrollBarVisibility}"/>
                            <ScrollBar Name="PART_VerticalScrollBar" Grid.Column="1" Maximum="{TemplateBinding ScrollableHeight}" ViewportSize="{TemplateBinding ViewportHeight}" Value="{TemplateBinding VerticalOffset}" Visibility="{TemplateBinding ComputedVerticalScrollBarVisibility}"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="GridViewColumnHeaderGripper" TargetType="Thumb">
            <!-- Column Header Divider -->
            <Setter Property="Width" Value="18"/>
            <Setter Property="Background" Value="#404040"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Thumb}">
                        <Border Padding="{TemplateBinding Padding}" Background="Transparent">
                            <Rectangle HorizontalAlignment="Center" Width="1" Fill="{TemplateBinding Background}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="{x:Type GridViewColumnHeader}" TargetType="GridViewColumnHeader">
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Foreground" Value="#EBEBEB"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="GridViewColumnHeader">
                        <Grid>
                            <!-- ColumnHeader NoEvent -->
                            <Border Name="HeaderBorder" BorderThickness="0,0,0,0" BorderBrush="#ABADB3" Background="#202020" Padding="5,0,2,0">
                                <ContentPresenter Name="HeaderContent" Margin="0,0,0,1" VerticalAlignment="{TemplateBinding VerticalContentAlignment}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" RecognizesAccessKey="True" SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
                            </Border>
                            <Thumb x:Name="PART_HeaderGripper" HorizontalAlignment="Right" Margin="0,0,-9,0" Style="{StaticResource GridViewColumnHeaderGripper}"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <!--Column Even Mouseover -->
                            <Trigger Property="IsMouseOver" Value="true">
                                <Setter TargetName="HeaderBorder" Property="Background" Value="#555555"/>
                            </Trigger>
                            <!--Column Is Pressed -->
                            <Trigger Property="IsPressed" Value="true">
                                <Setter TargetName="HeaderBorder" Property="Background" Value="#555555"/>
                                <Setter TargetName="HeaderContent" Property="Margin" Value="1,1,0,0"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter Property="Foreground" Value="{DynamicResource {x:Static SystemColors.GrayTextBrushKey}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="Role" Value="Floating">
                    <Setter Property="Opacity" Value="0.7"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="GridViewColumnHeader">
                                <Canvas Name="PART_FloatingHeaderCanvas">
                                    <Rectangle Fill="#60000000" Width="{TemplateBinding ActualWidth}" Height="{TemplateBinding ActualHeight}"/>
                                </Canvas>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
                <Trigger Property="Role" Value="Padding">
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="GridViewColumnHeader">
                                <!-- Column Header Empty Space -->
                                <Border Name="HeaderBorder" BorderThickness="0,0,0,0" BorderBrush="#ABADB3" Background="#202020"/>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="{x:Type ListView}" TargetType="ListView">
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.CanContentScroll" Value="true"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Foreground" Value="#EBEBEB"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListView">
                        <!-- Background -->
                        <Border Name="Border" BorderThickness="1" BorderBrush="#ABADB3" Background="#343447">
                            <ScrollViewer Style="{DynamicResource {x:Static GridView.GridViewScrollViewerStyleKey}}">
                                <ItemsPresenter />
                            </ScrollViewer>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsGrouping" Value="true">
                                <Setter Property="ScrollViewer.CanContentScroll" Value="false"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter TargetName="Border" Property="Background" Value="Green"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="{x:Type ListViewItem}" TargetType="ListViewItem">
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListViewItem">
                        <Border Name="Border" Padding="2" SnapsToDevicePixels="true" Background="Transparent">
                            <GridViewRowPresenter VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="true">
                                <Setter TargetName="Border" Property="Background" Value="#4590CE"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="true">
                                <Setter TargetName="Border" Property="Background" Value="#4590CE"/>
                                <Setter TargetName="Border" Property="Cursor" Value="Hand"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!--#endregion Listview -->
        <!--#region Wait Indicator -->
        <Storyboard x:Key="Storyboard" RepeatBehavior="Forever">
            <DoubleAnimationUsingKeyFrames BeginTime="00:00:00" Storyboard.TargetName="Control_NetInterface_Ell_Wait" Storyboard.TargetProperty="(UIElement.RenderTransform).(TransformGroup.Children)[2].(RotateTransform.Angle)">
                <SplineDoubleKeyFrame KeyTime="00:00:01" Value="360"/>
            </DoubleAnimationUsingKeyFrames>
        </Storyboard>
        <!--#endregion Wait Indicator -->
    </Window.Resources>
    <Window.Triggers>
        <!--#region Wait Indicator -->
        <EventTrigger RoutedEvent="FrameworkElement.Loaded">
            <BeginStoryboard Storyboard="{StaticResource Storyboard}"/>
        </EventTrigger>
        <!--#endregion Wait Indicator -->
    </Window.Triggers>
    <Grid>
        <DockPanel LastChildFill="True" >
            <StackPanel DockPanel.Dock="Left" Width="550" HorizontalAlignment="Left" Margin="50,0,0,0" >
                <StackPanel Orientation="Horizontal" Margin="0,25,0,0">
                    <TextBlock FontSize="24" FontFamily="Segoe UI Light" Foreground="#EBEBEB" Text="Microsoft Azure Stack" />
                    <TextBlock FontSize="11.5" FontFamily="Segoe UI Light" Foreground="#EBEBEB" Margin="210,3,0,0" Text="Installer UI version: " />
                    <TextBlock x:Name="Control_Header_Tbl_Version" FontSize="11.5" FontFamily="Segoe UI Light" Foreground="#FF4590CE" Margin="0,3,0,0" />
                </StackPanel>
                <TextBlock FontSize="44" FontFamily="Segoe UI Light" Foreground="#EBEBEB" Text="Development Kit" />
                <TextBlock x:Name="Control_Header_Tbl_Title" FontSize="20" FontFamily="Segoe UI" Foreground="#EBEBEB" Margin="0,50,0,30" Text="Title" />
                <!--#region Mode-->
                <StackPanel x:Name="Control_Mode_Stp" Visibility="Visible">
                    <StackPanel Orientation="Horizontal">
                        <Button x:Name="Control_Mode_Btn_Left" Width="250" Height="250" Margin="0,0,50,0">
                            <StackPanel VerticalAlignment="Top">
                                <TextBlock x:Name="Control_Mode_Tbl_LeftTitle" TextWrapping="Wrap" Padding="15" FontSize="18" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="LeftTitle" />
                                <TextBlock x:Name="Control_Mode_Tbl_LeftContent" TextWrapping="Wrap" Padding="15,0,15,15" FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="LeftContent"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="Control_Mode_Btn_Right" Width="250" Height="250" >
                            <StackPanel VerticalAlignment="Top">
                                <TextBlock x:Name="Control_Mode_Tbl_RightTitle" TextWrapping="Wrap" Padding="15" FontSize="18" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="RightTitle" />
                                <TextBlock x:Name="Control_Mode_Tbl_RightContent" TextWrapping="Wrap" Padding="15,0,15,15" FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="RightContent"/>
                            </StackPanel>
                        </Button>
                    </StackPanel>
                    <TextBlock FontSize="11.5" FontFamily="Segoe UI Light" Foreground="#EBEBEB" Padding="0,40,0,0" TextWrapping="Wrap" ><Run Text="The installer UI for the Azure Stack Development Kit is an open sourced script based on WPF and PowerShell. Additions to the toolkit can be submitted as Pull Request to the "/><Run Foreground="#FF4590CE" Text="AzureStack-Tools repository"/><Run Text="."/></TextBlock>
                </StackPanel>
                <!--#endregion Mode-->
                <!--#region Prepare-->
                <StackPanel x:Name="Control_Prepare_Stp" HorizontalAlignment="Left" Visibility="Collapsed">
                    <StackPanel Height="320">
                        <TextBlock FontSize="16" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Cloudbuilder.vhdx" Margin="0,0,0,10" />
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <TextBox x:Name="Control_Prepare_Tbx_Vhdx" BorderBrush="#ABADB3" Width="440" />
                            <Button x:Name="Control_Prepare_Btn_Vhdx" Content="Browse" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="10,0,0,0" />
                        </StackPanel>
                        <CheckBox x:Name="Control_Prepare_Chb_Drivers" VerticalAlignment="Center" Content="Add drivers" Margin="0,0,0,10" />
                        <StackPanel x:Name="Control_Prepare_Stp_Drivers" Orientation="Horizontal" Margin="25,0,0,10" Visibility="Collapsed">
                            <TextBox x:Name="Control_Prepare_Tbx_Drivers" BorderBrush="#ABADB3" Width="415" />
                            <Button x:Name="Control_Prepare_Btn_Drivers" Content="Browse" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="10,0,0,0" />
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="Control_Prepare_Btn_Previous" Content="Previous" Height="23.5" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" />
                        <Button x:Name="Control_Prepare_Btn_Next" Content="Next" Height="23.5" Width="100" Margin="10,0,0,0" HorizontalAlignment="Center" VerticalAlignment="Center" IsEnabled="False"/>
                    </StackPanel>
                </StackPanel>
                <!--#endregion Prepare-->
                <!--#region Unattend-->
                <StackPanel x:Name="Control_Unattend_Stp" HorizontalAlignment="Left" Visibility="Collapsed">
                    <StackPanel Height="320" Width="550">
                        <CheckBox x:Name="Control_Unattend_Chb_LocalAdmin" VerticalAlignment="Center" Content="Configure local admin account" Margin="0,0,0,10" IsChecked="True" />
                        <StackPanel x:Name="Control_Unattend_Stp_LocalAdmin" Visibility="Visible">
                            <StackPanel Orientation="Horizontal" Margin="25,0,0,10">
                                <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Username:" Width="120" HorizontalAlignment="Left"/>
                                <TextBox BorderBrush="#ABADB3" Width="405" Text="Administrator" IsEnabled="False" />
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="25,0,0,10">
                                <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Password:" Width="120" HorizontalAlignment="Left"/>
                                <PasswordBox x:Name="Control_Unattend_Pwb_LocalPassword" BorderBrush="#ABADB3" Width="405" />
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="25,0,0,10">
                                <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Confirm Password:" Width="120" HorizontalAlignment="Left"/>
                                <PasswordBox x:Name="Control_Unattend_Pwb_LocalPasswordConfirm" BorderBrush="#ABADB3" Width="405" IsEnabled="False" />
                            </StackPanel>
                        </StackPanel>
                        <CheckBox x:Name="Control_Unattend_Chb_Computername" VerticalAlignment="Center" Content="Computername" Margin="0,0,0,10" />
                        <StackPanel x:Name="Control_Unattend_Stp_Computername" Visibility="Collapsed">
                            <TextBox x:Name="Control_Unattend_Tbx_Computername" BorderBrush="#ABADB3" Width="405" Text="" HorizontalAlignment="Right"/>
                        </StackPanel>
                        <CheckBox x:Name="Control_Unattend_Chb_TimeZone" VerticalAlignment="Center" Content="Time Zone" Margin="0,0,0,10" />
                        <StackPanel x:Name="Control_Unattend_Stp_TimeZone" Visibility="Collapsed">
                            <StackPanel Orientation="Horizontal" Margin="25,0,0,10">
                                <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Timezone:" Width="120" HorizontalAlignment="Left"/>
                                <ComboBox x:Name="Control_Unattend_Cbx_Timezone" Foreground="#EBEBEB" FontFamily="Segoe UI" FontSize="14" Width="405"  />
                            </StackPanel>
                        </StackPanel>
                        <CheckBox x:Name="Control_Unattend_Chb_StaticIP" VerticalAlignment="Center" Content="Static IP configuration" Margin="0,0,0,10" />
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="Control_Unattend_Btn_Previous" Content="Previous" Height="23.5" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" />
                        <Button x:Name="Control_Unattend_Btn_Next" Content="Next" Height="23.5" Width="100" Margin="10,0,0,0" HorizontalAlignment="Center" VerticalAlignment="Center" IsEnabled="False"/>
                    </StackPanel>
                </StackPanel>
                <!--#endregion Prepare-->
                <!--#region Credentials-->
                <StackPanel x:Name="Control_Creds_Stp" HorizontalAlignment="Left" Visibility="Collapsed">
                    <StackPanel Height="320">
                        <TextBlock FontSize="16" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Identity Provider" Margin="0,0,0,10"/>


                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Type:" Width="120" HorizontalAlignment="Left"/>
                            <ComboBox Width="430" x:Name="Control_Creds_Cbx_Idp" Foreground="#EBEBEB" FontFamily="Segoe UI" FontSize="14" >
                            </ComboBox>
                        </StackPanel>
                        <StackPanel x:Name="Control_Creds_Stp_AAD" Visibility="Visible">
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                                <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="AAD Directory:" Width="120" HorizontalAlignment="Left"/>
                                <TextBox x:Name="Control_Creds_Tbx_AADTenant" BorderBrush="#ABADB3" Width="430"  IsEnabled="False" />
                            </StackPanel>
                        </StackPanel>
                        <StackPanel x:Name="Control_Creds_Stp_LocalPassword" Visibility="Visible">
                            <TextBlock FontSize="16" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Local Administrator Password" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                                <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Password:" Width="120" HorizontalAlignment="Left"/>
                                <Grid>
                                    <PasswordBox x:Name="Control_Creds_Pwb_LocalPassword" BorderBrush="#ABADB3" Width="430"/>
                                    <Path x:Name="Control_Creds_Pth_LocalPassword" SnapsToDevicePixels="False" StrokeThickness="3" Data="M2,10 L8,16 L15,5" Stroke="#92D050" Margin="300,0,0,0" Visibility="Hidden"/>
                                </Grid>
                            </StackPanel>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="Control_Creds_Btn_Previous" Content="Previous" Height="23.5" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        <Button x:Name="Control_Creds_Btn_Next" Content="Next" Height="23.5" Width="100" Margin="10,0,0,0" HorizontalAlignment="Center" VerticalAlignment="Center" IsEnabled="False"/>
                    </StackPanel>
                </StackPanel>
                <!--#endregion Credentials-->
                <!--#region NetworkInterface-->
                <StackPanel x:Name="Control_NetInterface_Stp" HorizontalAlignment="Left" Visibility="Collapsed">
                    <StackPanel Height="320">
                        <TextBlock FontSize="16" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Select a network adapter" Margin="0,0,0,10"/>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto" />
                                </Grid.RowDefinitions>
                                <ListView x:Name="Control_NetInterface_Lvw_Nics" MinHeight="100" MaxHeight="200" Width="550" Background="#343447" SelectionMode="Single">
                                    <ListView.View>
                                        <GridView>
                                            <GridViewColumn Header="Name" Width="100" DisplayMemberBinding ="{Binding 'Name'}" />
                                            <GridViewColumn Header="Status" Width="100" DisplayMemberBinding ="{Binding 'ConnectionState'}"  />
                                            <GridViewColumn Header="IPv4Address" Width="130" DisplayMemberBinding ="{Binding 'Ipv4Address'}" />
                                            <GridViewColumn Header="Gateway" Width="130" DisplayMemberBinding ="{Binding 'Ipv4DefaultGateway'}" />
                                            <GridViewColumn Header="DHCP" Width="80" DisplayMemberBinding ="{Binding 'DHCP'}" />
                                        </GridView>
                                    </ListView.View>
                                </ListView>
                                <StackPanel x:Name="Control_NetInterface_Stp_Wait" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,15,0,0">
                                    <Ellipse x:Name="Control_NetInterface_Ell_Wait" Width="20" Height="20" StrokeDashArray="0,2" StrokeDashCap="Round" StrokeThickness="3.5" RenderTransformOrigin="0.5,0.5" >
                                        <Ellipse.RenderTransform>
                                            <TransformGroup>
                                                <ScaleTransform/>
                                                <SkewTransform/>
                                                <RotateTransform/>
                                            </TransformGroup>
                                        </Ellipse.RenderTransform>
                                        <Ellipse.Stroke>
                                            <LinearGradientBrush EndPoint="0.445,0.997" StartPoint="0.555,0.103">
                                                <GradientStop Color="#343447" Offset="0"/>
                                                <GradientStop Color="#4590CE" Offset="1"/>
                                            </LinearGradientBrush>
                                        </Ellipse.Stroke>
                                    </Ellipse>
                                    <TextBlock Text="Getting network interface properties. Please wait..." Margin="10,0,0,0" FontFamily="Segoe UI" FontSize="14" Foreground="#EBEBEB" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Grid>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <TextBlock x:Name="Control_NetInterface_Tbl_Warning" Width="550" FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" TextWrapping="Wrap" Text="" HorizontalAlignment="Left" />
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="Control_NetInterface_Btn_Previous" Content="Previous" Height="23.5" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" />
                        <Button x:Name="Control_NetInterface_Btn_Next" Content="Next" Height="23.5" Width="100" Margin="10,0,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </StackPanel>
                </StackPanel>
                <!--#endregion NetworkInterface-->
                <!--#region NetConfig-->
                <StackPanel x:Name="Control_NetConfig_Stp" HorizontalAlignment="Left" Visibility="Collapsed">
                    <StackPanel Height="320">
                        <RadioButton x:Name="Control_NetConfig_Rbt_DHCP" GroupName="NetworkConfig" VerticalContentAlignment="Center" Cursor="Hand" Margin="0,0,0,5" IsChecked="True">
                            <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="DHCP" Width="100" HorizontalAlignment="Left" Padding="5,0,0,0"/>
                        </RadioButton>
                        <RadioButton x:Name="Control_NetConfig_Rbt_Static" GroupName="NetworkConfig" VerticalContentAlignment="Center" Cursor="Hand" Margin="0,0,0,10" >
                            <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Static" Width="100" HorizontalAlignment="Left" Padding="5,0,0,0"/>
                        </RadioButton>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Ip Address:" Width="120" HorizontalAlignment="Left"/>
                            <TextBox x:Name="Control_NetConfig_Tbx_IpAddress" BorderBrush="#ABADB3" Width="430" IsEnabled="False"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Gateway:" Width="120" HorizontalAlignment="Left"/>
                            <TextBox x:Name="Control_NetConfig_Tbx_Gateway" BorderBrush="#ABADB3" Width="430" IsEnabled="False"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10" x:Name="Control_NetConfig_Stp_DNS">
                            <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="DNS:" Width="120" HorizontalAlignment="Left"/>
                            <TextBox x:Name="Control_NetConfig_Tbx_DNS" BorderBrush="#ABADB3" Width="430" IsEnabled="False"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Time Server IP:" Width="120" HorizontalAlignment="Left"/>
                            <TextBox x:Name="Control_NetConfig_Tbx_TimeServer" BorderBrush="#ABADB3" Width="430" />
                        </StackPanel>
                        <StackPanel x:Name="Control_NetConfig_Stp_Optional">
                            <TextBlock FontSize="16" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Optional Configuration" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                                <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="VLAN ID:" Width="120" HorizontalAlignment="Left"/>
                                <TextBox x:Name="Control_NetConfig_Tbx_VlanID" BorderBrush="#ABADB3" Width="430" />
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                                <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="DNS Forwarder IP:" Width="120" HorizontalAlignment="Left"/>
                                <TextBox x:Name="Control_NetConfig_Tbx_DnsForwarder" BorderBrush="#ABADB3" Width="430"/>
                            </StackPanel>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="Control_NetConfig_Btn_Previous" Content="Previous" Height="23.5" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" />
                        <Button x:Name="Control_NetConfig_Btn_Next" Content="Next" Height="23.5" Width="100" Margin="10,0,0,0" HorizontalAlignment="Center" VerticalAlignment="Center" IsEnabled="False" />
                    </StackPanel>
                </StackPanel>
                <!--#endregion NetConfig-->
                <!--#region Job-->
                <StackPanel x:Name="Control_Job_Stp" HorizontalAlignment="Left" Visibility="Collapsed">
                    <StackPanel Height="320">
                        <ProgressBar x:Name="Control_Job_Pgb_Progress" Height="23.5" Width="550" Background="#1B4D72" Minimum="0" Maximum="100" Value="0" Foreground="#4F91CD" BorderThickness="0"/>
                        <TextBlock x:Name="Control_Job_Tbl_Current" FontSize="12" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="" HorizontalAlignment="Left" Margin="0,10,0,0" />
                        <TextBlock x:Name="Control_Job_Tbl_Details" FontSize="12" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="" TextWrapping="Wrap" HorizontalAlignment="Left" Margin="0,10,0,0" />
                        <StackPanel x:Name="Control_Job_Stp_Netbxnda" Visibility="Collapsed">
                            <StackPanel Orientation="Horizontal">
                                <Path  SnapsToDevicePixels="False" StrokeThickness="1" Data="M13,10H11V6H13M13,14H11V12H13M20,2H4A2,2 0 0,0 2,4V22L6,18H20A2,2 0 0,0 22,16V4C22,2.89 21.1,2 20,2Z" Fill="Orange" Margin="0,3,10,0" Visibility="Visible"/>
                                <TextBlock  TextWrapping="Wrap" FontSize="16" FontFamily="Segoe UI" Foreground="#EBEBEB" HorizontalAlignment="Left" Margin="0,0,0,10" Text="An update cannot be downloaded" />
                            </StackPanel>
                            <TextBlock TextWrapping="Wrap" FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" HorizontalAlignment="Left" Margin="0,0,0,10" Text="The update could not be downloaded directly from this machine. Please download the update from the following url:" />
                            <TextBox  TextWrapping="Wrap" FontSize="14" FontFamily="Segoe UI" Foreground="#A0A0A0" HorizontalAlignment="Left" Margin="0,0,0,10" Padding="5" Width="550" IsReadOnly="True" BorderBrush="#ABADB3" Text="https://go.microsoft.com/fwlink/?linkid=852544" />
                            <TextBlock TextWrapping="Wrap" FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" HorizontalAlignment="Left" Margin="0,0,0,10" Text="Save the file on this host, click the browse button and select the executable to continue." />
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                                <TextBox x:Name="Control_Job_Tbx_Netbxnda" BorderBrush="#ABADB3" Width="440" IsReadOnly="True" />
                                <Button x:Name="Control_Job_Btn_Netbxnda" Content="Browse" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="10,0,0,0" />
                            </StackPanel>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="Control_Job_Btn_Previous" Content="Previous" Height="23.5" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" />
                        <Button x:Name="Control_Job_Btn_Next" Content="Next" Height="23.5" Width="100" Margin="10,0,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </StackPanel>
                </StackPanel>
                <!--#endregion Job-->
                <!--#region Summary-->
                <StackPanel x:Name="Control_Summary_Stp" HorizontalAlignment="Left" Visibility="Collapsed">
                    <StackPanel Height="320">
                            <TextBlock x:Name="Control_Summary_Tbl_Header1" TextWrapping="Wrap" FontSize="16" FontFamily="Segoe UI" Foreground="#EBEBEB" HorizontalAlignment="Left" Margin="0,0,0,10" />
                            <TextBox x:Name="Control_Summary_Tbx_Content1" TextWrapping="Wrap" FontSize="14" FontFamily="Segoe UI" Foreground="#A0A0A0" HorizontalAlignment="Left" Margin="0,0,0,10" Padding="5" Width="550" IsReadOnly="True" Visibility="Collapsed" BorderBrush="#ABADB3" />
                        <StackPanel Orientation="Horizontal">
                            <Path x:Name="Control_Summary_Pth_Content1"  SnapsToDevicePixels="False" StrokeThickness="1" Data="M13,10H11V6H13M13,14H11V12H13M20,2H4A2,2 0 0,0 2,4V22L6,18H20A2,2 0 0,0 22,16V4C22,2.89 21.1,2 20,2Z" Fill="Orange" Margin="0,3,10,0" Visibility="Collapsed"/>
                            <TextBlock x:Name="Control_Summary_Tbl_Content1"  TextWrapping="Wrap" FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" HorizontalAlignment="Left" Margin="0,0,0,10" Width="550" />
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="Control_Summary_Btn_Previous" Content="Previous" Height="23.5" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" />
                        <Button x:Name="Control_Summary_Btn_Next" Content="Next" Height="23.5" Width="100" Margin="10,0,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </StackPanel>
                </StackPanel>
                <!--#endregion Summary-->
                <!--#region Reboot-->
                <StackPanel x:Name="Control_Reboot_Stp" HorizontalAlignment="Left" Visibility="Collapsed">
                    <StackPanel Height="280">
                        <TextBlock FontSize="16" FontFamily="Segoe UI" Foreground="#EBEBEB" Text="Select a onetime boot option" Margin="0,0,0,10"/>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <ListView x:Name="Control_Reboot_Lvw_Options" Height="100" Width="550" SelectionMode="Single" >
                                <ListView.View>
                                    <GridView>
                                        <GridViewColumn Header="Name" Width="540" DisplayMemberBinding ="{Binding 'Description'}" />
                                    </GridView>
                                </ListView.View>
                            </ListView>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                            <TextBlock FontSize="14" FontFamily="Segoe UI" Foreground="#EBEBEB" TextWrapping="Wrap" HorizontalAlignment="Left"/>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="Control_Reboot_Btn_Previous" Content="Previous" Height="23.5" Width="100" HorizontalAlignment="Center" VerticalAlignment="Center" />
                        <Button x:Name="Control_Reboot_Btn_Next" Content="Reboot" Height="23.5" Width="100" Margin="10,0,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </StackPanel>
                </StackPanel>
                <!--#endregion Reboot-->
            </StackPanel>
        </DockPanel>
    </Grid>
</Window>
'@
#endregion

#region Get XAML and create variables
Add-Type -AssemblyName PresentationFramework
Add-Type -assemblyname system.DirectoryServices.accountmanagement 

[xml]$Xaml = $Xaml

$Reader = (New-Object System.Xml.XmlNodeReader $Xaml)
$Form = [Windows.Markup.XamlReader]::Load( $Reader )

$syncHash = [hashtable]::Synchronized(@{})

$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | Where-Object {$_.name -like "Control_*"} | ForEach-Object { $syncHash.Add($_.Name,$Form.FindName($_.Name) )}
#endregion

#region Data
#region Version
$syncHash.Control_Header_Tbl_Version.Text = $Text_Generic.Version
#endregion

#region AuthEndpoints
$AuthEndpoints = @{
    'Azure Cloud'= @{
        'Endpoint'='https://login.windows.net'
        }
    'Azure China Cloud'= @{
        'Endpoint'='https://login.chinacloudapi.cn'
        }   
    'ADFS'= @{
        'Endpoint'='https://adfs.local.azurestack.external'
        }
}

$AuthEndpoints.GetEnumerator() | ForEach-Object {
$syncHash.Control_Creds_Cbx_Idp.AddChild($_.Key)
}
#endregion AuthEndpoints

#region TimeZones
$syncHash.Timezones = [System.TimeZoneInfo]::GetSystemTimeZones()

$syncHash.Timezones | ForEach-Object {
$syncHash.Control_Unattend_Cbx_Timezone.AddChild($_.DisplayName)
}
#endregion TimeZones

#region Regex
$Regex = @{}
$Regex.Fqdn = @'
(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)
'@
$Regex.Computername = @'
(?![0-9]{1,15}$)[a-zA-Z0-9-]{1,15}
'@
$Regex.IpAddress = @'
([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]
'@
$Regex.IpAddressCidr = @'
([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2])
'@
#endregion Regex
#endregion Data

#region ScriptBlocks

$S_Initialize = {
bcdedit
}

$S_NetInterfaces = {
    $syncHash.Control_NetInterface_Lvw_Nics.Dispatcher.Invoke([action]{$syncHash.Control_NetInterface_Lvw_Nics.Items.Clear()},"Normal")
    $NetInterfaces = @()
    Get-NetAdapter | Foreach-Object {

        $NetAdapter = $_
        $NetIPInterface = Get-NetIPInterface -InterfaceIndex $_.ifIndex -AddressFamily IPv4
        $NetIPConfiguration = Get-NetIPConfiguration -InterfaceIndex $_.ifIndex
        $NetIPAddress =  Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4

        $properties = New-Object -TypeName PSObject
        $properties | Add-Member -Type NoteProperty -Name Name -Value $NetAdapter.Name
        $properties | Add-Member -Type NoteProperty -Name InterfaceIndex -Value $NetAdapter.InterfaceIndex
        $properties | Add-Member -Type NoteProperty -Name MacAddress -Value $NetAdapter.MacAddress
        $properties | Add-Member -Type NoteProperty -Name ConnectionState -Value $NetIPInterface.ConnectionState
        $properties | Add-Member -Type NoteProperty -Name Ipv4Address -Value $NetIPConfiguration.Ipv4Address.IpAddress
        $properties | Add-Member -Type NoteProperty -Name Ipv4PrefixLength -Value $NetIPAddress.PrefixLength
        $properties | Add-Member -Type NoteProperty -Name Ipv4DefaultGateway -Value $NetIPConfiguration.IPv4DefaultGateway.NextHop
        $properties | Add-Member -Type NoteProperty -Name DHCP -Value $NetIPInterface.DHCP
        $properties | Add-Member -Type NoteProperty -Name DNS -Value ($NetIPConfiguration.DNSServer | Where-Object {$_.AddressFamily -eq "2"}).ServerAddresses
        $properties | Add-Member -Type NoteProperty -Name InterfaceMetric -Value $NetIPInterface.InterfaceMetric

        $NetInterfaces += $properties
    }
 
    
    $syncHash.Control_NetInterface_Stp_Wait.Dispatcher.Invoke([action]{$syncHash.Control_NetInterface_Stp_Wait.Visibility="Collapsed"},"Normal")
    $NetInterfaces | Sort-Object ConnectionState, IPv4DefaultGateway, InterfaceMetric, Ipv4Address -Descending | ForEach-Object {
        $syncHash.Control_NetInterface_Lvw_Nics.Dispatcher.Invoke([action]{$syncHash.Control_NetInterface_Lvw_Nics.AddChild($_)},"Normal")
        }
}

$S_PrepareVHDX = {
    
    #region Validate disk space for expanding cloudbuilder.vhdx
    # Progress
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='15'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Verify diskspace..'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")
    
    #Logic
    $Prepare_Vhdx_Path = $syncHash.Control_Prepare_Tbx_Vhdx.Dispatcher.Invoke('Normal',[Func[Object]]{$syncHash.Control_Prepare_Tbx_Vhdx.Text})
    $Prepare_HardDisk_DriveLetter = (Get-Item $Prepare_Vhdx_Path).PSDrive.Name
    $Prepare_HardDisk_Size = [math]::truncate((get-volume -DriveLetter $Prepare_HardDisk_DriveLetter).Size / 1GB)
    $Prepare_HardDisk_SizeRemaining = [math]::truncate((get-volume -DriveLetter $Prepare_HardDisk_DriveLetter).SizeRemaining / 1GB)
    $Prepare_Vhdx_Size = [math]::truncate((Get-Item $Prepare_Vhdx_Path).Length / 1GB)
    $Prepare_HardDisk_SizeReq = 120
    $Prepare_HardDisk_ActualReq = ($Prepare_HardDisk_SizeReq - $Prepare_Vhdx_Size)

    #Error
    if (($Prepare_HardDisk_SizeReq - $Prepare_Vhdx_Size) -ge $Prepare_HardDisk_SizeRemaining)
        {
        $Prepare_details = "Cloudbuilder.vhdx is placed on $Prepare_HardDisk_DriveLetter. When you boot from CloudBuilder.vhdx the virtual hard disk will be expanded to its full size of $Prepare_HardDisk_SizeReq GB. $Prepare_HardDisk_DriveLetter does not contain enough free space. You need $Prepare_HardDisk_ActualReq GB of free disk space for a succesfull boot from CloudBuilder.vhdx, but $Prepare_HardDisk_DriveLetter only has $Prepare_HardDisk_SizeRemaining GB remaining. Ensure Cloudbuilder.vhdx is placed on a local disk that contains enough free space and rerun this script."
        $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Inlines.Add("Error: Insufficient disk space")},"Normal")
        $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Inlines.Add((New-Object System.Windows.Documents.LineBreak))},"Normal")
        $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Inlines.Add($Prepare_details)},"Normal")
        Break
        }
    #endregion

    #region Remove boot from previous deployment
    #Progress
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='30'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Checking for previous boot entries..'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")

    #Logic
    $bootOptions = bcdedit /enum  | Select-String 'path' -Context 2,1
    $bootOptions | ForEach-Object {
    if ((($_.Context.PreContext[1] -replace '^device +') -like '*CloudBuilder.vhdx*') -and (($_.Context.PostContext[0] -replace '^description +') -eq 'Azure Stack'))
        {
        $BootID = '"' + ($_.Context.PreContext[0] -replace '^identifier +') + '"'
        bcdedit /delete $BootID
        }
    }
    #endregion

    #region Mount VHDX
    #ProgressBar
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='45'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Mount VHDX..'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")

    #Logic
    # Disable Autoplay
    If (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\EventHandlersDefaultSelection\StorageOnArrival") {
        $Autoplay = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\EventHandlersDefaultSelection\StorageOnArrival").'(default)'
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\EventHandlersDefaultSelection\StorageOnArrival" -Name '(default)' -Type String -Value 'MSTakeNoAction'
        }

    $Prepare_Vhdx_Mounted = Mount-DiskImage -ImagePath $Prepare_Vhdx_Path -PassThru | Get-DiskImage | Get-Disk    
    $Prepare_Vhdx_Partitions = $Prepare_Vhdx_Mounted | Get-Partition | Sort-Object -Descending -Property Size
    $Prepare_Vhdx_DriveLetter = $Prepare_Vhdx_Partitions[0].DriveLetter

    # Reset Autoplay to original value
    If (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\EventHandlersDefaultSelection\StorageOnArrival"){
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers\EventHandlersDefaultSelection\StorageOnArrival" -Name '(default)' -Type String -Value $Autoplay
        }

    #Error
    #$Prepare_details = "Creating new boot entry for CloudBuilder.vhdx"
    #$syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Inlines.Add("The boot configuration contains an existing CloudBuilder.vhdx entry")},"Normal")
    #$syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Inlines.Add((New-Object System.Windows.Documents.LineBreak))},"Normal")
    #$syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Inlines.Add($Prepare_details)},"Normal")
    #endregion

    #region Add bootfiles to OS 
    #ProgressBar
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='55'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Add bootfiles to OS..'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")

    #Logic
    bcdboot $Prepare_Vhdx_DriveLetter':\Windows' 

    #endregion

    #region Add Boot entry
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='70'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Add a boot entry for Azure Stack..'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")

    #Logic
    $bootOptions = bcdedit /enum  | Select-String 'path' -Context 2,1
    $bootOptions | ForEach-Object {
        if (((($_.Context.PreContext[1] -replace '^device +') -eq ('partition='+$Prepare_Vhdx_DriveLetter+':') -or (($_.Context.PreContext[1] -replace '^device +') -like '*CloudBuilder.vhdx*')) -and (($_.Context.PostContext[0] -replace '^description +') -ne 'Azure Stack'))) {
            $BootID = '"' + ($_.Context.PreContext[0] -replace '^identifier +') + '"'
            bcdedit /set $BootID description "Azure Stack"
        }
    }
    #endregion

    #region Unattend

    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='80'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Apply autounattend..'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")

    #Logic
    $Unattend_Apply_LocalAdmin = $SyncHash.Control_Unattend_Chb_LocalAdmin.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Unattend_Chb_LocalAdmin.IsChecked})
    if ($SyncHash.Control_Unattend_Chb_Computername.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Unattend_Chb_Computername.IsChecked})){
        $U_Unattend_input_computername = $SyncHash.Control_Unattend_Tbx_Computername.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Unattend_Tbx_Computername.Text})
    }
    else {
        $U_Unattend_input_computername = $null
    }
    $Unattend_Apply_StaticIP = $SyncHash.Control_Unattend_Chb_StaticIP.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Unattend_Chb_StaticIP.IsChecked})
    if ($SyncHash.Control_Unattend_Chb_Timezone.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Unattend_Chb_Timezone.IsChecked})){
        $U_unattend_input_timezone_value = $SyncHash.Control_Unattend_Cbx_Timezone.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Unattend_Cbx_Timezone.SelectedItem})
        $U_Unattend_input_timezone = ($syncHash.Timezones | Where-Object {$_.DisplayName -eq $U_unattend_input_timezone_value}).ID
    }
    else {
        $U_Unattend_input_timezone = "Pacific Standard Time"
    }

    $U_Unattend_input_macaddress = $SyncHash.Control_NetInterface_Lvw_Nics.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_NetInterface_Lvw_Nics.SelectedItem.MacAddress})
    $U_Unattend_input_ipaddress = $SyncHash.Control_NetConfig_Tbx_IpAddress.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_NetConfig_Tbx_IpAddress.Text})
    $U_Unattend_input_gateway = $SyncHash.Control_NetConfig_Tbx_Gateway.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_NetConfig_Tbx_Gateway.Text})
    $U_Unattend_input_dns = $SyncHash.Control_NetConfig_Tbx_DNS.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_NetConfig_Tbx_DNS.Text})
    $U_Unattend_input_adminpassword = $SyncHash.Control_Unattend_Pwb_LocalPassword.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Unattend_Pwb_LocalPassword.Password})
    $U_Unattend_input_productkey ="74YFP-3QFB3-KQT8W-PMXWJ-7M648"

    #region minimal
    [XML]$U_Unattend = @"
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <UserData>
        <ProductKey>
          <Key>$U_Unattend_input_productkey</Key>
        </ProductKey>
        <FullName>Microsoft</FullName>
        <Organization>Microsoft</Organization>
        <AcceptEula>true</AcceptEula>
      </UserData>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-TerminalServices-RDP-WinStationExtensions" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <UserAuthentication>0</UserAuthentication>
    </component>
    <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <fDenyTSConnections>false</fDenyTSConnections>
    </component>
    <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Description>Enable LocalAdmin Account</Description>
          <Order>1</Order>
          <Path>cmd /c net user administrator /active:yes</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
    <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <IEHardenAdmin>false</IEHardenAdmin>
      <IEHardenUser>false</IEHardenUser>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <TimeZone>$U_Unattend_input_timezone</TimeZone>
      <ComputerName>$U_Unattend_input_computername</ComputerName>
    </component>
    <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <FirewallGroups>
        <FirewallGroup wcm:action="add" wcm:keyValue="EnableRemoteDesktop">
          <Active>true</Active>
          <Group>@FirewallAPI.dll,-28752</Group>
          <Profile>all</Profile>
        </FirewallGroup>
      </FirewallGroups>
    </component>
  </settings>
</unattend>
"@
    #endregion minimal

    #region specialize
    [XML]$U_Unattend_specialize_IPAddress=@"
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="specialize">
    <component name="Microsoft-Windows-TCPIP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <Interfaces>
            <Interface wcm:action="add">
	            <Identifier>$U_Unattend_input_macaddress</Identifier>
                <Ipv4Settings>
                    <DhcpEnabled>false</DhcpEnabled>
                </Ipv4Settings>
                <Ipv6Settings>
                    <DhcpEnabled>false</DhcpEnabled>
                </Ipv6Settings>
                <UnicastIpAddresses>
                    <IpAddress wcm:action="add" wcm:keyValue="1">$U_Unattend_input_ipaddress</IpAddress>
                </UnicastIpAddresses>
                <Routes>
                    <Route wcm:action="add">
                        <Identifier>0</Identifier>
                        <Prefix>0.0.0.0/0</Prefix>
                        <NextHopAddress>$U_Unattend_input_gateway</NextHopAddress>
                    </Route>
                </Routes>
            </Interface>
        </Interfaces>
    </component>
  </settings>
</unattend>
"@

    [XML]$U_Unattend_specialize_DNS=@"
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="specialize">
    <component name="Microsoft-Windows-DNS-Client" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <Interfaces>
            <Interface wcm:action="add">
                <Identifier>$U_Unattend_input_macaddress</Identifier>
                <DNSServerSearchOrder>
                    <IpAddress wcm:action="add" wcm:keyValue="1">$U_Unattend_input_dns</IpAddress>
                </DNSServerSearchOrder>
                <EnableAdapterDomainNameRegistration>true</EnableAdapterDomainNameRegistration>
                <DisableDynamicUpdate>false</DisableDynamicUpdate>
            </Interface>
        </Interfaces>
    </component>
  </settings>
</unattend>
"@
    #endregion specialize

    #region oobeSystem
    [XML]$U_Unattend_oobeSysten_AdminPassword=@"
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <UserAccounts>
            <AdministratorPassword>
                <Value>$U_Unattend_input_adminpassword</Value>
                <PlainText>true</PlainText>
            </AdministratorPassword>
        </UserAccounts>
        <OOBE>
            <SkipMachineOOBE>true</SkipMachineOOBE>
        </OOBE>
    </component>
  </settings>
</unattend>
"@
    #endregion oobeSystem

    
    if($Unattend_Apply_LocalAdmin) {
        $U_Unattend.unattend.AppendChild($U_Unattend.ImportNode($U_Unattend_oobeSysten_AdminPassword.unattend.settings, $true))
        }

    if($Unattend_Apply_StaticIP) {
        ($U_Unattend.unattend.settings | Where-Object {$_.pass -eq 'Specialize'}).AppendChild($U_Unattend.ImportNode($U_Unattend_specialize_IPAddress.unattend.settings.component, $true))
        ($U_Unattend.unattend.settings | Where-Object {$_.pass -eq 'Specialize'}).AppendChild($U_Unattend.ImportNode($U_Unattend_specialize_DNS.unattend.settings.component, $true))
        }

    $U_Unattend.OuterXml | Out-File ($Prepare_Vhdx_DriveLetter+":\unattend.xml") -Encoding ascii -Force
    #endregion

    #region Add drivers
    #Condition
    $Prepare_ApplyDrivers = $SyncHash.Control_Prepare_Chb_Drivers.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Prepare_Chb_Drivers.IsChecked})
    $Prepare_Drivers_Path = $SyncHash.Control_Prepare_Tbx_Drivers.Dispatcher.Invoke('Normal',[Func[Object]]{$SyncHash.Control_Prepare_Tbx_Drivers.Text})
    if ($Prepare_ApplyDrivers) {
        $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='90'},"Normal")
        $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Add drivers..'},"Normal")
        $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")
        foreach ($subdirectory in $Prepare_Drivers_Path) {
            Add-WindowsDriver -Driver $subdirectory -Path "$($Prepare_Vhdx_DriveLetter):\" -Recurse
        }
    }
    #endregion

    #region Finalize
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='100'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Completed'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")
    $syncHash.Control_Job_Btn_Next.Dispatcher.Invoke([action]{$syncHash.Control_Job_Btn_Next.IsEnabled=$true},"Normal")
    #endregion
}

$S_Netbxnda = {
    
    # Verify if netbxnda.inf is used
    # Progress

    $syncHash.Control_Job_Tbx_Netbxnda.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbx_Netbxnda.Text=''},"Normal")
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='20'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Verify driver..'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")
    
    #Logic
    $SelectedNetAdapterIterfaceIndex = $syncHash.Control_NetInterface_Lvw_Nics.Dispatcher.Invoke('Normal',[Func[Object]]{$syncHash.Control_NetInterface_Lvw_Nics.SelectedItem.InterfaceIndex})
    $SelectedNetAdapter = Get-NetAdapter -InterfaceIndex $SelectedNetAdapterIterfaceIndex
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='40'},"Normal")
    $PnPDevice = Get-PnpDevice -InstanceId $SelectedNetAdapter.PnPDeviceID
    # netbxnda.inf used in selected NIC?
    If ((Get-PnpDeviceProperty -InputObject $PnPDevice -KeyName DEVPKEY_Device_DriverInfPath).Data -eq "netbxnda.inf") {
        $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='60'},"Normal")
        $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Downloading update..'},"Normal")
        try {
            Start-Transcript -Path C:\CloudDeployment\Setup\netbxnda.txt -Append
            $filepath = "$env:TEMP\netbxnda.exe"
            Invoke-WebRequest "https://go.microsoft.com/fwlink/?linkid=852544" -OutFile $filepath

            $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='80'},"Normal")
            $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Applying update..'},"Normal")

            Invoke-Expression $filepath
            Remove-Item -Path $filepath
            Stop-Transcript
        }
        catch {
                $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='60'},"Normal")
                $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Downloading update..'},"Normal")
                $syncHash.Control_Job_Stp_Netbxnda.Dispatcher.Invoke([action]{$synchash.Control_Job_Stp_Netbxnda.Visibility='Visible'},"Normal")
                Break
        }
    }

    #region Finalize
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='100'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Completed'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")
    $syncHash.Control_Job_Btn_Next.Dispatcher.Invoke([action]{$syncHash.Control_Job_Btn_Next.IsEnabled=$true},"Normal")
    #endregion
    
}

$S_NetbxndaOffline = {

    $filepath = $syncHash.Control_Job_Tbx_Netbxnda.Dispatcher.Invoke('Normal',[Func[Object]]{$syncHash.Control_Job_Tbx_Netbxnda.Text})

    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='80'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Applying update..'},"Normal")

    Start-Transcript -Path C:\CloudDeployment\Setup\netbxnda.txt -Append 
    Invoke-Expression $filepath
    Remove-Item -Path $filepath
    Stop-Transcript

    #region Finalize
    $syncHash.Control_Job_Pgb_Progress.Dispatcher.Invoke([action]{$syncHash.Control_Job_Pgb_Progress.Value='100'},"Normal")
    $synchash.Control_Job_Tbl_Current.Dispatcher.Invoke([action]{$synchash.Control_Job_Tbl_Current.Text='Completed'},"Normal")
    $syncHash.Control_Job_Tbl_Details.Dispatcher.Invoke([action]{$syncHash.Control_Job_Tbl_Details.Clear()},"Normal")
    $syncHash.Control_Job_Btn_Next.Dispatcher.Invoke([action]{$syncHash.Control_Job_Btn_Next.IsEnabled=$true},"Normal")
    #endregion
}

#endregion ScriptBlocks

#region Nested Runspace Jobs
$Runspace_Jobs_Properties =[runspacefactory]::CreateRunspace()
$Runspace_Jobs_Properties.Name = "Jobs"
$Runspace_Jobs_Properties.ApartmentState = "STA"
$Runspace_Jobs_Properties.ThreadOptions = "ReuseThread"         
$Runspace_Jobs_Properties.Open()
$Runspace_Jobs_Properties.SessionStateProxy.SetVariable("syncHash",$syncHash)  
$Runspace_Jobs = [PowerShell]::Create()
#endregion

#region Functions
Function F_Initialize {
    Write-Host "Initialize environment. Please wait." -NoNewline -ForegroundColor Cyan

    # Initialize runspace
    $Runspace_Jobs.Commands.Clear()
    $Runspace_Jobs.AddScript($S_Initialize) | Out-Null
    $Runspace_Jobs.Runspace = $Runspace_Jobs_Properties
    $Runspace_Jobs_Output = $Runspace_Jobs.BeginInvoke()

    Write-Host "." -NoNewline -ForegroundColor Cyan

    # Get environment details CloudBuilder
    if (test-path "C:\CloudDeployment\Setup\InstallAzureStackPOC.ps1") {
        if(!(test-path "C:\CloudDeployment\ECEngine\EnterpriseCloudEngine.psd1")) {
            # Deployment not initialized
            $Script:Initialized="CloudBuilder_Install"
            $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Mode_Title
            $syncHash.Control_Mode_Tbl_LeftTitle.Text = $Text_Install.Mode_LeftTitle
            $syncHash.Control_Mode_Tbl_LeftContent.Text = $Text_Install.Mode_LeftContent
        }
        else {
            # Import module to check current deployment status
            Import-Module "C:\CloudDeployment\ECEngine\EnterpriseCloudEngine.psd1" -Force -Verbose:$false
            $actionProgress = Get-ActionProgress -ActionType Deployment
            # Deployment not started
            if (!($actionProgress)) {
                $Script:Initialized="CloudBuilder_Install"
                $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Mode_Title
                $syncHash.Control_Mode_Tbl_LeftTitle.Text = $Text_Install.Mode_LeftTitle
                $syncHash.Control_Mode_Tbl_LeftContent.Text = $Text_Install.Mode_LeftContent
            }
            elseif($actionProgress.Attribute("Status").Value -eq 'Success') {
                # Deployment completed
                $Script:Initialized="CloudBuilder_Completed_GatherLogs"
                $syncHash.Control_Header_Tbl_Title.Text = $Text_Completed.Mode_Title
                $syncHash.Control_Mode_Tbl_LeftTitle.Text = $Text_Completed.Mode_LeftTitle
                $syncHash.Control_Mode_Tbl_LeftContent.Text = $Text_Completed.Mode_LeftContent
            }
            # Deployment in progress or stopped
            else{
                # Not deployed with deployment UI
                if(!(test-path "C:\CloudDeployment\Rerun\config.xml")) {
                    New-Item C:\CloudDeployment\Rerun -type directory -Force
                    '<config status="rerun" run="0"/>' | Out-File C:\CloudDeployment\Rerun\config.xml
                    $Script:Initialized="CloudBuilder_Rerun"
                    $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Mode_Title
                    $syncHash.Control_Mode_Tbl_LeftTitle.Text = $Text_Rerun.Mode_LeftTitle
                    $syncHash.Control_Mode_Tbl_LeftContent.Text = $Text_Rerun.Mode_LeftContent
                }
                # Deployed with deployment UI
                else {
                    $Status = [XML](Get-Content "C:\CloudDeployment\Rerun\config.xml")
                    # Contains only 1 or 2 deployment logs
                    if ($status.config.status -eq "Rerun" -and [int]$status.config.run -le 2) {
                        $Script:Initialized="CloudBuilder_Rerun"
                        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Mode_Title
                        $syncHash.Control_Mode_Tbl_LeftTitle.Text = $Text_Rerun.Mode_LeftTitle
                        $syncHash.Control_Mode_Tbl_LeftContent.Text = $Text_Rerun.Mode_LeftContent
                    }
                    # Contains 2 or more deployment logs
                    else {
                        $Script:Initialized="CloudBuilder_Rerun_GatherLogs"
                        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Mode_Title_Logs
                        $syncHash.Control_Mode_Tbl_LeftTitle.Text = $Text_Rerun.Mode_LeftTitle_Logs
                        $syncHash.Control_Mode_Tbl_LeftContent.Text = $Text_Rerun.Mode_LeftContent_Logs
                    }
                }
            }
        }

        # Reboot options
        F_Reboot_Options
        $syncHash.Control_Mode_Tbl_RightTitle.Text = $Text_Install.Mode_RightTitle
        $syncHash.Control_Mode_Tbl_RightContent.Text = $Text_Install.Mode_RightContent
    }
    # Booted from vhdx, but not CloudBuilder.vhdx
    elseif ((get-disk | Where-Object {$_.isboot -eq $true}).Model -match 'Virtual Disk') {
        Write-Host "The server is currently already booted from a virtual hard disk, to boot the server from the CloudBuilder.vhdx you will need to run this script on an Operating System that is installed on the physical disk of this server." -ForegroundColor Red
        Exit
    }

    # Booted in the SafeOS
    else {
        $Script:Initialized="SafeOS"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Mode_Title
        $syncHash.Control_Mode_Tbl_LeftTitle.Text = $Text_SafeOS.Mode_LeftTitle
        $syncHash.Control_Mode_Tbl_LeftContent.Text = $Text_SafeOS.Mode_LeftContent
        $syncHash.Control_Mode_Tbl_RightTitle.Text = $Text_SafeOS.Mode_RightTitle
        $syncHash.Control_Mode_Tbl_RightContent.Text = $Text_SafeOS.Mode_RightContent
    }

Write-Host "." -ForegroundColor Cyan

}

function F_Browse_File {
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

function F_Browse_Folder {
    Param(
    [string]$title
    )

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $Script:F_Browse_obj = New-Object System.Windows.Forms.FolderBrowserDialog
    $Script:F_Browse_obj.Description = $title
    $Script:F_Browse_obj.ShowDialog()
}

Function F_Regex {
    Param(
        [string]$field,
        [string]$regex,
        [switch]$nocondition,
        [switch]$validpath,
        [string]$field_value,
        [string]$message
    )

    $Script:validation_error = $false

    if ($regex) {
        if (($field_value.Length -gt 0) -and ($field_value -notmatch "^($regex)$")) {
            $Script:validation_error = $true
        }
    }

    if ($nocondition) {
        $Script:validation_error = $true
    }

    if ($validpath) {
        if (!(test-path $field_value)) {
            $Script:validation_error = $true
        }
    }

    # Validation Actions
    $control = ($syncHash.GetEnumerator() | Where-Object {$_.name -eq $field})

    if ($Script:validation_error) {
            $tooltip = new-object System.Windows.Controls.ToolTip
            $tooltip.Background = "#282D32"
            $tooltip.Foreground = "white"
            $tooltip.BorderThickness = 1
            $tooltip.Padding = 15
            $tooltip.HorizontalOffset = -5
            $tooltip.VerticalOffset = -50
            $tooltip.Content = $message
            $tooltip.Placement = "left"
            $control.value.ToolTip = $tooltip
            $control.value.BorderBrush = "Red"
    }
        else {
            #parent stackpanel
            $control.value.ToolTip = $null
            $control.value.BorderBrush="#ABADB3"
    }
}

Function F_Reboot_Options {
    $syncHash.Control_Reboot_Btn_Next.IsEnabled = $false
    $syncHash.Control_Reboot_Lvw_Options.Items.Clear()

    $bootOptions = bcdedit /enum  | Select-String 'path' -Context 2,1

    $bootOptions | ForEach-Object {
        $bootOption = New-Object -TypeName PSObject
        $bootOption | Add-Member -Type NoteProperty -Name Description -Value ($_.Context.PostContext[0] -replace '^description +')
        $bootOption | Add-Member -Type NoteProperty -Name ID -Value ($_.Context.PreContext[0] -replace '^identifier +')

        $syncHash.Control_Reboot_Lvw_Options.AddChild($bootOption)
    }
}

Function F_Reboot {
    #region Boot
    $BootID = '"' + $syncHash.Control_Reboot_Lvw_Options.SelectedItem.ID + '"'
    bcdedit /bootsequence $BootID
    $Form.Close()
    Restart-Computer -Force
    #endregion
}

Function F_Verify_LocalAdminCreds {
    $dsa = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
    $pass = $syncHash.Control_Creds_Pwb_LocalPassword.Password
    if ($dsa.ValidateCredentials('Administrator', $pass)){
    }
    else {
        F_Regex -field 'Control_Creds_Pwb_LocalPassword' -field_value $syncHash.Control_Creds_Pwb_LocalPassword.Password -nocondition -message $Text_Generic.Regex_LocalAdmin
    }
}

Function F_VerifyFields_Creds {
    if (
        ($syncHash.Control_Creds_Cbx_Idp.SelectedItem -eq 'ADFS' -and
        ($syncHash.Control_Creds_Pwb_LocalPassword.Password.Length -gt 0)) -or
        (
        $syncHash.Control_Creds_Cbx_Idp.SelectedItem -ne 'ADFS' -and
        $syncHash.Control_Creds_Cbx_Idp.SelectedItem -and
        ($syncHash.Control_Creds_Tbx_AADTenant.Text -and ($syncHash.Control_Creds_Tbx_AADTenant.BorderBrush.color -ne "#FFFF0000")) -and
        ($syncHash.Control_Creds_Pwb_LocalPassword.Password.Length -gt 0))
    ) {
        $syncHash.Control_Creds_Btn_Next.IsEnabled = $true
    }
    Else {
        $syncHash.Control_Creds_Btn_Next.IsEnabled = $false
    }
}

Function F_VerifyFields_NetConfig {
    if ($Script:Initialized -eq "SafeOS"){
        if (
            (
                ($syncHash.Control_NetConfig_Tbx_IpAddress.Text -and ($syncHash.Control_NetConfig_Tbx_IpAddress.BorderBrush.color -ne "#FFFF0000")) -and
                ($syncHash.Control_NetConfig_Tbx_Gateway.Text -and ($syncHash.Control_NetConfig_Tbx_Gateway.BorderBrush.color -ne "#FFFF0000")) -and
                ($syncHash.Control_NetConfig_Tbx_DNS.Text -and ($syncHash.Control_NetConfig_Tbx_DNS.BorderBrush.color -ne "#FFFF0000"))
            )
            ) {$syncHash.Control_NetConfig_Btn_Next.IsEnabled = $true}
        Else {$syncHash.Control_NetConfig_Btn_Next.IsEnabled = $false}
    }
    else {
        if (
            (
                $syncHash.Control_NetConfig_Rbt_DHCP.IsChecked -eq $true -and
                ($syncHash.Control_NetConfig_Tbx_TimeServer.Text -and ($syncHash.Control_NetConfig_Tbx_TimeServer.BorderBrush.color -ne "#FFFF0000"))
            ) -or
            (
                $syncHash.Control_NetConfig_Rbt_Static.IsChecked -eq $true -and
                ($syncHash.Control_NetConfig_Tbx_IpAddress.Text -and ($syncHash.Control_NetConfig_Tbx_IpAddress.BorderBrush.color -ne "#FFFF0000")) -and
                ($syncHash.Control_NetConfig_Tbx_Gateway.Text -and ($syncHash.Control_NetConfig_Tbx_Gateway.BorderBrush.color -ne "#FFFF0000")) -and
                ($syncHash.Control_NetConfig_Tbx_TimeServer.Text -and ($syncHash.Control_NetConfig_Tbx_TimeServer.BorderBrush.color -ne "#FFFF0000"))
            )
            ) {$syncHash.Control_NetConfig_Btn_Next.IsEnabled = $true}
        Else {$syncHash.Control_NetConfig_Btn_Next.IsEnabled = $false}
    }
}

Function F_VerifyFields_Prepare {
    $EnableButton=$false

    if ($syncHash.Control_Prepare_Tbx_Vhdx.Text){$EnableButton=$true}

    if ($syncHash.Control_Prepare_Tbx_Vhdx.Text -and $syncHash.Control_Prepare_Chb_Drivers.IsChecked) {
        if ($syncHash.Control_Prepare_Tbx_Drivers.Text){$EnableButton=$true}
        else {$EnableButton=$false}
    }

    if ($EnableButton){$syncHash.Control_Prepare_Btn_Next.IsEnabled = $true}
    Else {$syncHash.Control_Prepare_Btn_Next.IsEnabled = $false}
}

Function F_VerifyFields_Unattend {

    $LocalAdmin = $true
    $Computername = $true
    $Timezone = $true

    if ($syncHash.Control_Unattend_Chb_LocalAdmin.IsChecked) {
        if ($syncHash.Control_Unattend_Pwb_LocalPassword.Password -and
            $syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.Password){$LocalAdmin=$true}
        else {$LocalAdmin=$false}
    }

    if ($syncHash.Control_Unattend_Chb_Computername.IsChecked) {
        if ($syncHash.Control_Unattend_Tbx_Computername.Text){$Computername=$true}
        else {$Computername=$false}
    }

    if ($syncHash.Control_Unattend_Chb_Timezone.IsChecked) {
        if ($syncHash.Control_Unattend_Cbx_TimeZone.SelectedValue){$Timezone=$true}
        else {$Timezone=$false}
    }

    if ($LocalAdmin -eq $true -and $Computername -eq $true -and $Timezone -eq $true){ $syncHash.Control_Unattend_Btn_Next.IsEnabled = $true}
    Else {$syncHash.Control_Unattend_Btn_Next.IsEnabled = $false}
}

Function F_CopyNicProperties {
    $syncHash.Control_NetConfig_Tbx_IpAddress.IsEnabled = $true
    $syncHash.Control_NetConfig_Tbx_Gateway.IsEnabled = $true
    $syncHash.Control_NetConfig_Tbx_DNS.IsEnabled = $true
    $syncHash.Control_NetConfig_Tbx_IpAddress.Text=$syncHash.Control_NetInterface_Lvw_Nics.SelectedItem.Ipv4Address + '/' + $syncHash.Control_NetInterface_Lvw_Nics.SelectedItem.Ipv4PrefixLength
    $syncHash.Control_NetConfig_Tbx_Gateway.Text=$syncHash.Control_NetInterface_Lvw_Nics.SelectedItem.Ipv4DefaultGateway
    $SyncHash.Control_NetConfig_Tbx_DNS.Text=$syncHash.Control_NetInterface_Lvw_Nics.SelectedItem.DNS[0]
}

Function F_GetNetworkID {
    $CIDRIPAddress = $syncHash.Control_NetConfig_Tbx_IpAddress.Text

    $ipBinary = $null
    $dottedDecimal = $null

    $IPAddress = $CIDRIPAddress.Split("/")[0] 
    $cidr = [convert]::ToInt32($CIDRIPAddress.Split("/")[1]) 

    $IPAddress.split(".") | ForEach-Object{$ipBinary=$ipBinary + $([convert]::toString($_,2).padleft(8,"0"))}

    if($cidr -le 32) {
        [Int[]]$array = (1..32) 
        for($i=0;$i -lt $array.length;$i++) { 
            if($array[$i] -gt $cidr){$array[$i]="0"}else{$array[$i]="1"} 
        }
        $smBinary =$array -join "" 
    }

    $netBits=$smBinary.indexOf("0") 
    if ($netBits -ne -1) { 
        #identify subnet boundaries 
        $binary = $($ipBinary.substring(0,$netBits).padright(32,"0"))
        $i = 0
        do {$dottedDecimal += "." + [string]$([convert]::toInt32($binary.substring($i,8),2)); $i+=8 } while ($i -le 24)
        $networkID = $dottedDecimal.substring(1) + "/" + $cidr.ToString()
    } 
    else { 
        #identify subnet boundaries 
        $binary = $($ipBinary) 
        $i = 0
        do {$dottedDecimal += "." + [string]$([convert]::toInt32($binary.substring($i,8),2)); $i+=8 } while ($i -le 24)

        $networkID = $dottedDecimal.substring(1) + "/" + $cidr.ToString()
    } 

    return $networkID
}

Function F_Summary {
    If ($Script:Initialized -eq "CloudBuilder_Install") {
        $syncHash.Control_Summary_Tbl_Header1.Text = $Text_Install.Summary_Content

        $syncHash.Control_Summary_Tbx_Content1.Visibility = "Visible"
        $syncHash.Control_Summary_Tbx_Content1.Text = $null

        $InstallScript += '$adminpass = ConvertTo-SecureString ' + "'" + ($syncHash.Control_Creds_Pwb_LocalPassword.PasswordChar.ToString() * $syncHash.Control_Creds_Pwb_LocalPassword.Password.Length) +"'" + '-AsPlainText -Force'
        $InstallScript += "`r`n"
        $InstallScript += 'cd C:\CloudDeployment\Setup'
        $InstallScript += "`r`n"
        $InstallScript += '.\InstallAzureStackPOC.ps1 -AdminPassword $adminpass'

        # Azure Cloud, or Azure China Cloud, or ADFS
        If ($synchash.Control_Creds_Cbx_Idp.SelectedItem -eq 'Azure Cloud') {
                $InstallScript += " -InfraAzureDirectoryTenantName "
                $InstallScript += $synchash.Control_Creds_Tbx_AADTenant.Text                
        }
        ElseIf ($synchash.Control_Creds_Cbx_Idp.SelectedItem -eq 'Azure China Cloud') {
                $InstallScript += " -InfraAzureDirectoryTenantName "
                $InstallScript += $synchash.Control_Creds_Tbx_AADTenant.Text
                $InstallScript += " -InfraAzureEnvironment AzureChinaCloud"
        }
        ElseIf ($synchash.Control_Creds_Cbx_Idp.SelectedItem -eq 'ADFS') {
                $InstallScript += " -UseADFS"
        }

        If ($synchash.Control_NetConfig_Rbt_Static.IsChecked) {
                $NetworkID = F_GetNetworkID
                $InstallScript += " -NatIPv4Subnet "
                $InstallScript += $NetworkID
                $InstallScript += " -NatIPv4Address "
                $InstallScript += $synchash.Control_NetConfig_Tbx_IpAddress.Text.Split("/")[0]
                $InstallScript += " -NatIPv4DefaultGateway "
                $InstallScript += $synchash.Control_NetConfig_Tbx_Gateway.Text
        }

        If ($synchash.Control_NetConfig_Tbx_VlanID.Text.Length -gt 0) {
                $InstallScript += " -PublicVlanId "
                $InstallScript += $synchash.Control_NetConfig_Tbx_VlanID.Text
        }

        If ($synchash.Control_NetConfig_Tbx_DnsForwarder.Text.Length -gt 0) {
                $InstallScript += " -DNSForwarder "
                $InstallScript += $synchash.Control_NetConfig_Tbx_DnsForwarder.Text
        }

        If ($synchash.Control_NetConfig_Tbx_TimeServer.Text.Length -gt 0) {
            $InstallScript += " -TimeServer "
            $InstallScript += $synchash.Control_NetConfig_Tbx_TimeServer.Text
        }

        $syncHash.Control_Summary_Tbx_Content1.Text = $InstallScript

        # Azure Cloud or Azure China Cloud
        If ($synchash.Control_Creds_Cbx_Idp.SelectedItem -ne 'ADFS') {
            $syncHash.Control_Summary_Pth_Content1.Visibility = "Visible"
            $syncHash.Control_Summary_Tbl_Content1.Width = "510"
            $SyncHash.Control_Summary_Tbl_Content1.Text = $Text_Install.Summary_Warning
        }
    }
    If ($Script:Initialized -eq "SafeOS") {
        $syncHash.Control_Summary_Tbl_Content1.Text = $Text_SafeOS.Summary_Content
    }
}

Function F_Install {

    #region wrapper
    $filepath = "$env:TEMP\wrapper.ps1"
    New-Item $filepath -type file -Force
    'Write-Host "Starting installation. This can take a moment. Please wait.." -ForegroundColor Cyan' | Add-Content $filepath
    "remove-item $filepath" | Add-Content $filepath
    #endregion wrapper

    #region disable non selected NICs
    if ($synchash.Control_NetInterface_Lvw_Nics.SelectedItem -and ($synchash.Control_NetInterface_Lvw_Nics.Items.count -gt 1)) {
        Write-Host "Disabling non selected NICs" -ForegroundColor Cyan
        $disable_nics = $synchash.Control_NetInterface_Lvw_Nics.Items | Where-Object {$_ -ne $synchash.Control_NetInterface_Lvw_Nics.SelectedItem}
        $disable_nics | ForEach-Object {
            $IntID = $_.InterfaceIndex
            Get-NetAdapter -InterfaceIndex $IntID | Disable-NetAdapter -Confirm:$false
        }
    }
    else {
        write-output "no NIC interface was selected"
        break
    }
    #endregion

    #region Install Arguments
    Write-Host "Defining installation parameters" -ForegroundColor Cyan 
           
    '$adminpass = ConvertTo-SecureString ' + "'" + $syncHash.Control_Creds_Pwb_LocalPassword.Password + "'" + ' -AsPlainText -Force' | Add-Content $filepath
    "cd C:\CloudDeployment\Setup" |  Add-Content $filepath
    ".\InstallAzureStackPOC.ps1" |  Add-Content $filepath -NoNewline
    ' -AdminPassword $adminpass' |  Add-Content $filepath -NoNewline

    # Azure Cloud, or Azure China Cloud, or ADFS
    If ($synchash.Control_Creds_Cbx_Idp.SelectedItem -eq 'Azure Cloud') {
        ' -InfraAzureDirectoryTenantName "' + $synchash.Control_Creds_Tbx_AADTenant.Text + '"' |  Add-Content $filepath -NoNewline
    }
    ElseIf ($synchash.Control_Creds_Cbx_Idp.SelectedItem -eq 'Azure China Cloud') {
        ' -InfraAzureDirectoryTenantName "' + $synchash.Control_Creds_Tbx_AADTenant.Text + '"' |  Add-Content $filepath -NoNewline
        ' -InfraAzureEnvironment AzureChinaCloud' |  Add-Content $filepath -NoNewline
    }
    ElseIf ($synchash.Control_Creds_Cbx_Idp.SelectedItem -eq 'ADFS') {
        ' -UseADFS' |  Add-Content $filepath -NoNewline
    }

    If ($synchash.Control_NetConfig_Rbt_Static.IsChecked) {
        $NetworkID = F_GetNetworkID
        ' -NatIPv4Subnet "' + $NetworkID + '"' |  Add-Content $filepath -NoNewline
        ' -NatIPv4Address "' + $synchash.Control_NetConfig_Tbx_IpAddress.Text.Split("/")[0] + '"' |  Add-Content $filepath -NoNewline
        ' -NatIPv4DefaultGateway "' + $synchash.Control_NetConfig_Tbx_Gateway.Text + '"' |  Add-Content $filepath -NoNewline
    }

    If ($synchash.Control_NetConfig_Tbx_VlanID.Text.Length -gt 0) {
        ' -PublicVlanId "' + $synchash.Control_NetConfig_Tbx_VlanID.Text + '"' |  Add-Content $filepath -NoNewline
    }

    If ($synchash.Control_NetConfig_Tbx_DnsForwarder.Text.Length -gt 0) {
        ' -DNSForwarder "' + $synchash.Control_NetConfig_Tbx_DnsForwarder.Text + '"' |  Add-Content $filepath -NoNewline
    }

    If ($synchash.Control_NetConfig_Tbx_TimeServer.Text.Length -gt 0) {
        ' -TimeServer "' + $synchash.Control_NetConfig_Tbx_TimeServer.Text + '"' |  Add-Content $filepath -NoNewline
    }
    Else {
        ' -TimeServer "' + 'pool.ntp.org' + '"' |  Add-Content $filepath -NoNewline
    }
 
    #endregion

    #region Rerun Count
    Write-Host "Log starting installation" -ForegroundColor Cyan

    New-Item C:\CloudDeployment\Rerun -type directory -Force
    '<config status="rerun" run="0"/>' | Out-File C:\CloudDeployment\Rerun\config.xml
    #endregion Rerun Count

    #region Install
    Start-Process powershell -ArgumentList "-noexit", "-file $filepath"
    #endregion

}

Function F_Rerun {

    #region Add one to config file for number of reruns
    [int]$Run = ([XML](Get-Content "C:\CloudDeployment\Rerun\config.xml")).config.run
    '<config status="rerun" run="' + ($Run+1) + '"/>' | Out-File C:\CloudDeployment\Rerun\config.xml
    #endregion

    #region Rerun
    Set-Location C:\CloudDeployment\Setup
    .\InstallAzureStackPOC.ps1 -Rerun
    #endregion
}

Function F_GetAzureStackLogs {
    Write-Host "Starting Get-AzureStackLog. This can take a moment. Please wait.." -ForegroundColor Cyan
    #region Logs
    Set-Location C:\CloudDeployment\AzureStackDiagnostics\Microsoft.AzureStack.Diagnostics.DataCollection
    Import-Module .\Microsoft.AzureStack.Diagnostics.DataCollection.psd1
    Get-AzureStackLogs -OutputPath C:\AzureStackLogs
    #endregion
}
#endregion Functions

#region Events

#region Events Mode
$syncHash.Control_Mode_Btn_Left.Add_Click({
    $syncHash.Control_Mode_Stp.Visibility = "Collapsed"
    if ($Script:Initialized -eq "SafeOS") {
        $syncHash.Control_Prepare_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Prepare_Title
    }
    elseif ($Script:Initialized -eq "CloudBuilder_Install") {
        $syncHash.Control_Creds_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Credentials_Title
    }
    elseif ($Script:Initialized -eq "CloudBuilder_Rerun") {
        $syncHash.Control_Summary_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Summary_Title
        $syncHash.Control_Summary_Tbl_Header1.Text = $Text_Rerun.Summary_Content
        $syncHash.Control_Summary_Btn_Next.Content = "Rerun"
    }
    elseif ($Script:Initialized -eq "CloudBuilder_Rerun_GatherLogs") {
        $syncHash.Control_Summary_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Summary_Title_Logs
        $syncHash.Control_Summary_Tbl_Header1.Text = $Text_Rerun.Summary_Content_Logs
        $syncHash.Control_Summary_Btn_Next.Content = "Gather Logs"
    }
    elseif ($Script:Initialized -eq "CloudBuilder_Completed_GatherLogs") {
        $syncHash.Control_Summary_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Completed.Summary_Title
        $syncHash.Control_Summary_Tbl_Header1.Text = $Text_Completed.Summary_Content
        $syncHash.Control_Summary_Btn_Next.Content = "Gather Logs"
    }
})

$syncHash.Control_Mode_Btn_Right.Add_Click({
    if ($Script:Initialized -eq "SafeOS") {
        Start-Process $Text_SafeOS.Mode_RightLink
    }
    else {
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Reboot_Title
        $syncHash.Control_Mode_Stp.Visibility = "Collapsed"
        $syncHash.Control_Reboot_Stp.Visibility = "Visible"
        F_Reboot_Options
    }
})
#endregion Events Mode

#region Events Prepare
$syncHash.Control_Prepare_Btn_Previous.Add_Click({
    $syncHash.Control_Prepare_Stp.Visibility = "Collapsed"
    $syncHash.Control_Mode_Stp.Visibility = "Visible"
    $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Mode_Title
})

$syncHash.Control_Prepare_Btn_Next.Add_Click({
    $syncHash.Control_Prepare_Stp.Visibility = "Collapsed"
    $syncHash.Control_Unattend_Stp.Visibility = "Visible"
    $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Unattend_Title
})

$syncHash.Control_Prepare_Btn_Vhdx.Add_Click({
    F_Browse_File -title "Select Cloudbuilder vhdx" -filter "*.vhdx|*.vhdx"
    if ($Script:F_Browse_obj.FileName) {
        $syncHash.Control_Prepare_Tbx_Vhdx.Text = $Script:F_Browse_obj.FileName
        if ((Get-DiskImage -ImagePath $syncHash.Control_Prepare_Tbx_Vhdx.Text).Attached) {
            F_Regex -field 'Control_Prepare_Tbx_Vhdx' -field_value $syncHash.Control_Prepare_Tbx_Vhdx.Text -nocondition -message $Text_SafeOS.Prepare_VHDX_IsMounted
            $syncHash.Control_Prepare_Btn_Next.IsEnabled = $false
        }
        else {
            F_Regex -field 'Control_Prepare_Tbx_Vhdx' -field_value $syncHash.Control_Prepare_Tbx_Vhdx.Text
            F_VerifyFields_Prepare
        }
    }
})

$syncHash.Control_Prepare_Tbx_Vhdx.Add_TextChanged({
    if ($syncHash.Control_Prepare_Tbx_Vhdx.Text.Length -gt 0) {
        F_Regex -field 'Control_Prepare_Tbx_Vhdx'-field_value $syncHash.Control_Prepare_Tbx_Vhdx.Text -validpath -message $Text_SafeOS.Prepare_VHDX_InvalidPath
        if (!($script:validation_error)){F_VerifyFields_Prepare}
        else {$syncHash.Control_Prepare_Btn_Next.IsEnabled = $false}
    }
})

$syncHash.Control_Prepare_Chb_Drivers.Add_Click({
    if ($syncHash.Control_Prepare_Chb_Drivers.IsChecked) {
        $syncHash.Control_Prepare_Stp_Drivers.Visibility = "Visible"
        F_VerifyFields_Prepare
    }
    else {
        $syncHash.Control_Prepare_Stp_Drivers.Visibility = "Collapsed"
        $syncHash.Control_Prepare_Tbx_Drivers.Clear()
        F_VerifyFields_Prepare
    }
})

$syncHash.Control_Prepare_Btn_Drivers.Add_Click({
    F_Browse_Folder -title "Select Driver Path"
    if ($Script:F_Browse_obj.SelectedPath) {
        $syncHash.Control_Prepare_Tbx_Drivers.Text = $Script:F_Browse_obj.SelectedPath
    }
})

$syncHash.Control_Prepare_Tbx_Drivers.Add_TextChanged({
    if ($syncHash.Control_Prepare_Tbx_Drivers.Text.Length -gt 0) {
        F_Regex -field 'Control_Prepare_Tbx_Drivers'-field_value $syncHash.Control_Prepare_Tbx_Drivers.Text -validpath -message $Text_SafeOS.Prepare_Drivers_InvalidPath
        if (!($script:validation_error)){F_VerifyFields_Prepare}
        else {$syncHash.Control_Prepare_Btn_Next.IsEnabled = $false}
    }
})
#endregion Events Prepare

#region Events Unattend
$syncHash.Control_Unattend_Btn_Previous.Add_Click({
    $syncHash.Control_Unattend_Stp.Visibility = "Collapsed"
    $syncHash.Control_Prepare_Stp.Visibility = "Visible"
    $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Prepare_Title
})

$syncHash.Control_Unattend_Btn_Next.Add_Click({
    F_Regex -field 'Control_Unattend_Tbx_Computername' -field_value $syncHash.Control_Unattend_Tbx_Computername.Text -regex $Regex.Computername -message $Text_Generic.Regex_Computername
    If (!($Script:validation_error)) {
        $syncHash.Control_Unattend_Stp.Visibility = "Collapsed"

        If ($syncHash.Control_Unattend_Chb_StaticIP.IsChecked){
            $syncHash.Control_NetInterface_Stp.Visibility = "Visible"
            $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.NetInterface_Title
            $syncHash.Control_NetInterface_Tbl_Warning.Text = $Text_SafeOS.NetInterface_Warning
            $syncHash.Control_NetInterface_Btn_Next.IsEnabled = $false
            $Runspace_Jobs.Commands.Clear()
            $Runspace_Jobs.AddScript($S_NetInterfaces) | Out-Null
            $Runspace_Jobs.Runspace = $Runspace_Jobs_Properties
            $Runspace_Jobs_Output = $Runspace_Jobs.BeginInvoke()
        }
        Else{
            $syncHash.Control_Job_Stp.Visibility = "Visible"
            $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Job_Title
            $syncHash.Control_Job_Btn_Next.IsEnabled = $false
            $Runspace_Jobs.Commands.Clear()
            $Runspace_Jobs.AddScript($S_PrepareVhdx) | Out-Null
            $Runspace_Jobs.Runspace = $Runspace_Jobs_Properties
            $Runspace_Jobs_Output = $Runspace_Jobs.BeginInvoke()
        }
    }
})

$syncHash.Control_Unattend_Chb_LocalAdmin.Add_Click({
    if ($syncHash.Control_Unattend_Chb_LocalAdmin.IsChecked) {
        $syncHash.Control_Unattend_Stp_LocalAdmin.Visibility = "Visible"
        $syncHash.Control_Unattend_Btn_Next.IsEnabled = $false
    }
    else {
        $syncHash.Control_Unattend_Stp_LocalAdmin.Visibility = "Collapsed"
        $syncHash.Control_Unattend_Pwb_LocalPassword.Clear()
        $syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.Clear()
        F_Regex -field 'Control_Unattend_Pwb_LocalPassword'
        $syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.IsEnabled = $false
        F_VerifyFields_Unattend
    }
})

$syncHash.Control_Unattend_Pwb_LocalPassword.Add_PasswordChanged({
    #Enable the confirmation box if the First box contains any characters
    If (($syncHash.Control_Unattend_Pwb_LocalPassword.Password) -and (!($syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.IsEnabled))) {
        $syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.IsEnabled = $true
    }
    #Match the password with the confirmation field (only if it contains a value) while typing
    If ($syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.Password) {
        If ($syncHash.Control_Unattend_Pwb_LocalPassword.Password -cne $syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.Password) {
            F_Regex -field 'Control_Unattend_Pwb_LocalPassword'-nocondition -message $Text_Generic.Password_NotMatch
            $syncHash.Control_Unattend_Btn_Next.IsEnabled = $false
        }
        Else {
            F_Regex -field 'Control_Unattend_Pwb_LocalPassword'
            F_Regex -field 'Control_Unattend_Pwb_LocalPasswordConfirm'
            F_VerifyFields_Unattend
        }
    }
})

$syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.Add_PasswordChanged({
    #Match the password with the confirmation field (only if it contains a value) while typing
    If ($syncHash.Control_Unattend_Pwb_LocalPassword.Password) {
        If ($syncHash.Control_Unattend_Pwb_LocalPasswordConfirm.Password -cne $syncHash.Control_Unattend_Pwb_LocalPassword.Password) {
            F_Regex -field 'Control_Unattend_Pwb_LocalPasswordConfirm'-nocondition -message $Text_Generic.Password_NotMatch
            $syncHash.Control_Unattend_Btn_Next.IsEnabled = $false
        }
        Else {
            F_Regex -field 'Control_Unattend_Pwb_LocalPasswordConfirm'
            F_Regex -field 'Control_Unattend_Pwb_LocalPassword'
            F_VerifyFields_Unattend
        }
    }
})

$syncHash.Control_Unattend_Chb_Computername.Add_Click({
    if ($syncHash.Control_Unattend_Chb_Computername.IsChecked) {
        $syncHash.Control_Unattend_Stp_Computername.Visibility = "Visible"
        $syncHash.Control_Unattend_Btn_Next.IsEnabled = $false
    }
    else {
        $syncHash.Control_Unattend_Stp_Computername.Visibility = "Collapsed"
        $syncHash.Control_Unattend_Tbx_Computername.Clear()
        F_VerifyFields_Unattend
    }
})

$syncHash.Control_Unattend_Tbx_Computername.Add_TextChanged({
    F_Regex -field 'Control_Unattend_Tbx_Computername' -field_value $syncHash.Control_Unattend_Tbx_Computername.Text -regex $Regex.Computername -message $Text_Generic.Regex_Computername
    F_VerifyFields_Unattend
})

$syncHash.Control_Unattend_Chb_Timezone.Add_Click({
    if ($syncHash.Control_Unattend_Chb_Timezone.IsChecked) {
        $syncHash.Control_Unattend_Stp_Timezone.Visibility = "Visible"
        $syncHash.Control_Unattend_Btn_Next.IsEnabled = $false
    }
    else {
        $syncHash.Control_Unattend_Stp_Timezone.Visibility = "Collapsed"
        $syncHash.Control_Unattend_Cbx_Timezone.SelectedItem = $null
        F_VerifyFields_Unattend
    }
})

$syncHash.Control_Unattend_Cbx_Timezone.Add_SelectionChanged({
    F_VerifyFields_Unattend
})
#endregion Events Unattend

#region Events Creds
$syncHash.Control_Creds_Btn_Previous.Add_Click({
    $syncHash.Control_Creds_Stp.Visibility = "Collapsed"
    $syncHash.Control_Mode_Stp.Visibility = "Visible"
    $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Mode_Title
})

$syncHash.Control_Creds_Btn_Next.Add_Click({
    F_Verify_LocalAdminCreds
    If (!($Script:validation_error)){
        $syncHash.Control_Creds_Stp.Visibility = "Collapsed"
        $syncHash.Control_NetInterface_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.NetInterface_Title
        $syncHash.Control_NetInterface_Tbl_Warning.Text = $Text_Install.NetInterface_Warning
        $syncHash.Control_NetInterface_Lvw_Nics.Items.Clear()
        $syncHash.Control_NetInterface_Btn_Next.IsEnabled = $false
        $Runspace_Jobs.Commands.Clear()
        $Runspace_Jobs.AddScript($S_NetInterfaces) | Out-Null
        $Runspace_Jobs.Runspace = $Runspace_Jobs_Properties
        $Runspace_Jobs_Output = $Runspace_Jobs.BeginInvoke()
    }
})

$syncHash.Control_Creds_Cbx_Idp.Add_SelectionChanged({
    If ($syncHash.Control_Creds_Cbx_Idp.SelectedItem -eq 'ADFS') {
        $syncHash.Control_Creds_Tbx_AADTenant.Clear()
        $syncHash.Control_Creds_Tbx_AADTenant.IsEnabled = $false
        $syncHash.Control_Creds_Pwb_LocalPassword.IsEnabled = $true
    }
    Else {
        $syncHash.Control_Creds_Tbx_AADTenant.Clear()
        $syncHash.Control_Creds_Tbx_AADTenant.IsEnabled = $true
        $syncHash.Control_Creds_Pwb_LocalPassword.IsEnabled = $true
    }
    F_VerifyFields_Creds
})

$syncHash.Control_Creds_Tbx_AADTenant.Add_TextChanged({
    F_Regex -field 'Control_Creds_Tbx_AADTenant' -field_value $syncHash.Control_Creds_Tbx_AADTenant.Text -regex $Regex.Fqdn -message $Text_Generic.Regex_Fqdn
    F_VerifyFields_Creds
})

$syncHash.Control_Creds_Pwb_LocalPassword.Add_PasswordChanged({
    F_Regex -field 'Control_Creds_Pwb_LocalPassword'
    F_VerifyFields_Creds
})
#endregion Events Creds

#region Events NetInterface
$syncHash.Control_NetInterface_Btn_Previous.Add_Click({
    $syncHash.Control_NetInterface_Stp.Visibility = "Collapsed"
    $syncHash.Control_NetInterface_Stp_Wait.Visibility = "Visible"
    If ($Script:Initialized -eq "SafeOS") {
        $syncHash.Control_Unattend_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Unattend_Title
    }
    Else {
        $syncHash.Control_Creds_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Credentials_Title
    }
})

$syncHash.Control_NetInterface_Btn_Next.Add_Click({
    $syncHash.Control_NetInterface_Stp.Visibility = "Collapsed"
    If ($Script:Initialized -eq "SafeOS") {
        $syncHash.Control_NetConfig_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.NetConfig_Title
        $SyncHash.Control_NetConfig_Rbt_Static.Visibility="Collapsed"
        $SyncHash.Control_NetConfig_Rbt_DHCP.Visibility="Collapsed"
        $SyncHash.Control_NetConfig_Stp_Optional.Visibility="Collapsed"
        F_CopyNicProperties
    }
    Else {
        $syncHash.Control_NetConfig_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.NetConfig_Title
        $syncHash.Control_NetConfig_Stp_DNS.Visibility="Collapsed"
    }
})

$syncHash.Control_NetInterface_Lvw_Nics.Add_SelectionChanged({
    $syncHash.Control_NetInterface_Btn_Next.IsEnabled = $true
})

#endregion Events NetInterface

#region Events NetConfig
$syncHash.Control_NetConfig_Btn_Previous.Add_Click({
    $syncHash.Control_NetConfig_Stp.Visibility = "Collapsed"
    if ($script:Initialized -eq "SafeOS") {
        $syncHash.Control_NetInterface_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.NetInterface_Title
    }
    if ($script:Initialized -eq "Cloudbuilder_Install") {
        $syncHash.Control_NetInterface_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.NetInterface_Title
    }
})

$syncHash.Control_NetConfig_Btn_Next.Add_Click({
    $syncHash.Control_NetConfig_Stp.Visibility = "Collapsed"
    if ($script:Initialized -eq "SafeOS"){
            $syncHash.Control_Job_Stp.Visibility = "Visible"
            $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Job_Title
            $syncHash.Control_Job_Btn_Next.IsEnabled = $false
            $Runspace_Jobs.Commands.Clear()
            $Runspace_Jobs.AddScript($S_PrepareVhdx) | Out-Null
            $Runspace_Jobs.Runspace = $Runspace_Jobs_Properties
            $Runspace_Jobs_Output = $Runspace_Jobs.BeginInvoke()
    }
    if ($script:Initialized -eq "Cloudbuilder_Install"){
        $syncHash.Control_Job_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Job_Title

        $syncHash.Control_Job_Btn_Next.IsEnabled = $false
        $Runspace_Jobs.Commands.Clear()
        $Runspace_Jobs.AddScript($S_Netbxnda) | Out-Null
        $Runspace_Jobs.Runspace = $Runspace_Jobs_Properties
        $Runspace_Jobs_Output = $Runspace_Jobs.BeginInvoke()
    }
})

$syncHash.Control_NetConfig_Rbt_DHCP.Add_Click({
    $syncHash.Control_NetConfig_Tbx_IpAddress.IsEnabled = $false
    $syncHash.Control_NetConfig_Tbx_IpAddress.Clear()
    $syncHash.Control_NetConfig_Tbx_Gateway.IsEnabled = $false
    $syncHash.Control_NetConfig_Tbx_Gateway.Clear()
    $syncHash.Control_NetConfig_Tbx_DNS.IsEnabled = $false
    $syncHash.Control_NetConfig_Tbx_DNS.Clear()
    F_VerifyFields_NetConfig
})

$syncHash.Control_NetConfig_Rbt_Static.Add_Click({
    $syncHash.Control_NetConfig_Tbx_IpAddress.IsEnabled = $true
    $syncHash.Control_NetConfig_Tbx_Gateway.IsEnabled = $true
    $syncHash.Control_NetConfig_Tbx_DNS.IsEnabled = $true

    if ($script:Initialized -eq "SafeOS"){
        F_CopyNicProperties
    }

    F_VerifyFields_NetConfig
})

$syncHash.Control_NetConfig_Tbx_IpAddress.Add_TextChanged({
    F_Regex -field 'Control_NetConfig_Tbx_IpAddress' -field_value $syncHash.Control_NetConfig_Tbx_IpAddress.Text -regex $Regex.IpAddressCidr -message $Text_Generic.Regex_IpAddressCidr
    F_VerifyFields_NetConfig
})

$syncHash.Control_NetConfig_Tbx_Gateway.Add_TextChanged({
    F_Regex -field 'Control_NetConfig_Tbx_Gateway' -field_value $syncHash.Control_NetConfig_Tbx_Gateway.Text -regex $Regex.IpAddress -message $Text_Generic.Regex_IpAddress
    F_VerifyFields_NetConfig
})

$syncHash.Control_NetConfig_Tbx_Dns.Add_TextChanged({
    F_Regex -field 'Control_NetConfig_Tbx_Dns' -field_value $syncHash.Control_NetConfig_Tbx_Dns.Text -regex $Regex.IpAddress -message $Text_Generic.Regex_IpAddress
    F_VerifyFields_NetConfig
})

$syncHash.Control_NetConfig_Tbx_TimeServer.Add_TextChanged({
    F_Regex -field 'Control_NetConfig_Tbx_TimeServer' -field_value $syncHash.Control_NetConfig_Tbx_TimeServer.Text -regex $Regex.IpAddress -message $Text_Generic.Regex_IpAddress
    F_VerifyFields_NetConfig
})

$syncHash.Control_NetConfig_Tbx_DnsForwarder.Add_TextChanged({
    F_Regex -field 'Control_NetConfig_Tbx_DnsForwarder' -field_value $syncHash.Control_NetConfig_Tbx_DnsForwarder.Text -regex $Regex.IpAddress -message $Text_Generic.Regex_IpAddress
    F_VerifyFields_NetConfig
})

#endregion Events NetConfig

#region Events Job
$syncHash.Control_Job_Btn_Previous.Add_Click({
    $syncHash.Control_Job_Stp.Visibility = "Collapsed"
    if ($Script:Initialized -eq "SafeOS"){
        $syncHash.Control_Prepare_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Prepare_Title
    }
    if ($Script:Initialized -eq "CloudBuilder_Install") {
        $syncHash.Control_NetConfig_Stp.Visibility = "Visible"
        $synchash.Control_Job_Stp_Netbxnda.Visibility="Collapsed"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.NetConfig_Title
    }
    if ($Script:Initialized -eq "CloudBuilder_Rerun_GatherLogs"){
        $syncHash.Control_Mode_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Mode_Title_Logs
    }
})

$syncHash.Control_Job_Btn_Next.Add_Click({
    $syncHash.Control_Job_Stp.Visibility = "Collapsed"

    if ($Script:Initialized -eq "SafeOS"){
        $syncHash.Control_Summary_Stp.Visibility = "Visible"
        $syncHash.Control_Summary_Btn_Previous.Content = "Reboot later"
        $syncHash.Control_Summary_Btn_Next.Content = "Reboot now"
        F_Summary
    }
    else {
        $syncHash.Control_Summary_Stp.Visibility = "Visible"
        $SyncHash.Control_Summary_Btn_Next.Content = "Deploy"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Summary_Title
        F_Summary
    }
})

$syncHash.Control_Job_Btn_Netbxnda.Add_Click({
    F_Browse_File -title "Select netbxnda.exe" -filter "netbxnda.exe|netbxnda.exe"
    if ($Script:F_Browse_obj.FileName) {
        $syncHash.Control_Job_Tbx_Netbxnda.Text = $Script:F_Browse_obj.FileName
        $syncHash.Control_Job_Stp_Netbxnda.Visibility = "Collapsed"
        $Runspace_Jobs.Commands.Clear()
        $Runspace_Jobs.AddScript($S_NetbxndaOffline) | Out-Null
        $Runspace_Jobs.Runspace = $Runspace_Jobs_Properties
        $Runspace_Jobs_Output = $Runspace_Jobs.BeginInvoke()
        }
})
#endregion Events Job

#region Events Summary
$syncHash.Control_Summary_Btn_Previous.Add_Click({
    $syncHash.Control_Summary_Stp.Visibility = "Collapsed"
    If ($Script:Initialized -eq "SafeOS") {
        $Form.Close()
    }
    ElseIf ($Script:Initialized -eq "CloudBuilder_Install") {
        $syncHash.Control_NetConfig_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.NetConfig_Title
    }
    ElseIf ($Script:Initialized -eq "CloudBuilder_Rerun") {
        $syncHash.Control_Mode_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Mode_Title
    }
    ElseIf ($Script:Initialized -eq "CloudBuilder_Rerun_GatherLogs"){
        $syncHash.Control_Mode_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Summary_Title_Logs
    }
    ElseIf ($Script:Initialized -eq "CloudBuilder_Completed_GatherLogs"){
        $syncHash.Control_Mode_Stp.Visibility = "Visible"
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Summary_Title_Logs
    }

})

$syncHash.Control_Summary_Btn_Next.Add_Click({
    If ($Script:Initialized -eq "SafeOS") {
        $Form.Close()
        Restart-Computer -Force
    }
    ElseIf ($Script:Initialized -eq "Cloudbuilder_Install") {
        $Form.Close()
        F_Install
    }
    ElseIf ($Script:Initialized -eq "CloudBuilder_Rerun") {
        $Form.Close()
        F_Rerun
    }
    ElseIf ($Script:Initialized -eq "CloudBuilder_Rerun_GatherLogs") {
        $Form.Close()
        F_GetAzureStackLogs
    }
    ElseIf ($Script:Initialized -eq "CloudBuilder_Completed_GatherLogs") {
        $Form.Close()
        F_GetAzureStackLogs
    }
})
#endregion Events NetConfig

#region Events Reboot
$syncHash.Control_Reboot_Btn_Previous.Add_Click({
    $syncHash.Control_Reboot_Stp.Visibility = "Collapsed"
    $syncHash.Control_Mode_Stp.Visibility = "Visible"

    if ($Script:Initialized -eq "CloudBuilder_Install") {
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Install.Mode_Title
    }
    elseif ($Script:Initialized -eq "CloudBuilder_Rerun") {
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Mode_Title
    }
    elseif ($Script:Initialized -eq "CloudBuilder_Rerun_GatherLogs") {
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Rerun.Mode_Title_Logs
    }
    elseif ($Script:Initialized -eq "CloudBuilder_Completed_GatherLogs") {
        $syncHash.Control_Header_Tbl_Title.Text = $Text_Completed.Mode_Title
    }
    elseif ($Script:Initialized -eq "SafeOS") {
        $syncHash.Control_Header_Tbl_Title.Text = $Text_SafeOS.Mode_Title
    }
})

$syncHash.Control_Reboot_Lvw_Options.Add_SelectionChanged({
    $syncHash.Control_Reboot_Btn_Next.IsEnabled = $true
})

$syncHash.Control_Reboot_Btn_Next.Add_Click({
    F_Reboot
})
#endregion Events Reboot

#endregion Events

F_Initialize

$Form.ShowDialog() | out-null