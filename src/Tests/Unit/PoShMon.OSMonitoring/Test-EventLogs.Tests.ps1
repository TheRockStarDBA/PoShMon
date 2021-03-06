$rootPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath ('..\..\..\') -Resolve
Remove-Module PoShMon -ErrorAction SilentlyContinue
Import-Module (Join-Path $rootPath -ChildPath "PoShMon.psd1")

class EventLogItemMock {
    [int]$EventCode
    [string]$SourceName
    [string]$User
    [datetime]$TimeGenerated
    [string]$Message

    EventLogItemMock ([int]$NewEventCode, [String]$NewSourceName, [String]$NewUser, [datetime]$NewTimeGenerated, [String]$NewMessage) {
        $this.EventCode = $NewEventCode;
        $this.SourceName = $NewSourceName;
        $this.User = $NewUser;
        $this.TimeGenerated = $NewTimeGenerated;
        $this.Message = $NewMessage;
    }

    [string] ConvertToDateTime([datetime]$something) {
        return $something.ToString()
    }
}

Describe "Test-EventLogs" {
    It "Should return a matching output structure" {
    
        Mock -CommandName Get-WmiObject -MockWith {
            $eventsCollection = @()

            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", (Get-Date), "Sample Message")
            return $eventsCollection
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'localhost'
                        OperatingSystem
                    }

        $actual = Test-EventLogs $poShMonConfiguration -WarningAction SilentlyContinue

        $actual.Keys.Count | Should Be 5
        $actual.ContainsKey("NoIssuesFound") | Should Be $true
        $actual.ContainsKey("OutputHeaders") | Should Be $true
        $actual.ContainsKey("OutputValues") | Should Be $true
        $actual.ContainsKey("SectionHeader") | Should Be $true
        $actual.ContainsKey("ElapsedTime") | Should Be $true
        $headers = $actual.OutputHeaders
        $headers.Keys.Count | Should Be 6
        $valuesGroup1 = $actual.OutputValues[0]
        $valuesGroup1.Keys.Count | Should Be 2
        $values1 = $valuesGroup1.GroupOutputValues
        $values1.Keys.Count | Should Be 6
        $values1.ContainsKey("EventID") | Should Be $true
        $values1.ContainsKey("InstanceCount") | Should Be $true
        $values1.ContainsKey("Source") | Should Be $true
        $values1.ContainsKey("User") | Should Be $true
        $values1.ContainsKey("Timestamp") | Should Be $true
        $values1.ContainsKey("Message") | Should Be $true
    }

    It "Should write the expected Verbose output" {
    
        Mock -CommandName Get-WmiObject -MockWith {
            $eventsCollection = @()

            return $eventsCollection
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-EventLogs $poShMonConfiguration -Verbose
        $output = $($actual = Test-EventLogs $poShMonConfiguration -Verbose) 4>&1

        $output.Count | Should Be 4
        $output[0].ToString() | Should Be "Initiating 'Critical Event Log Issues' Test..."
        $output[1].ToString() | Should Be "`tServer1"
        $output[2].ToString() | Should Be "`t`tNo Entries Found In Time Specified"
        $output[3].ToString() | Should Be "Complete 'Critical Event Log Issues' Test, Issues Found: No"
    }

    It "Should write the expected Warning output" {
    
        Mock -CommandName Get-WmiObject -MockWith {
            $eventsCollection = @()

            $date = Get-Date -Year 2017 -Month 1 -Day 1 -Hour 9 -Minute 30 -Second 15

            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", $date, "Sample Message")
            $eventsCollection += [EventLogItemMock]::new(456, "Test App2", "domain\user2", $date.AddSeconds(1), "Another Message")
            return $eventsCollection
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-EventLogs $poShMonConfiguration
        $output = $($actual = Test-EventLogs $poShMonConfiguration) 3>&1

        $output.Count | Should Be 2
        $output[0].ToString() | Should Be "`t`t123 : 1 : Test App : domain\user1 : 01 Jan 2017 9:30:15 AM - Sample Message"
        $output[1].ToString() | Should Be "`t`t456 : 1 : Test App2 : domain\user2 : 01 Jan 2017 9:30:16 AM - Another Message"
    }

    It "Should alert on items found" {
        
        Mock -CommandName Get-WmiObject -MockWith {
            $eventsCollection = @()

            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", (Get-Date), "Sample Message")
            return $eventsCollection
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-EventLogs $poShMonConfiguration -WarningAction SilentlyContinue
        
        $actual.NoIssuesFound | Should Be $false
    }
    It "Should group per server" {
        
        Mock -CommandName Get-WmiObject -MockWith {
            $eventsCollection = @()

            $date = Get-Date

            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", $date, "Sample Message")
            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", $date.AddMinutes(-1), "Sample Message")
            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", $date.AddMinutes(-2), "Another Sample Message")
            $eventsCollection += [EventLogItemMock]::new(456, "Test App", "domain\user1", $date.AddMinutes(-3), "Different Event Code")

            return $eventsCollection
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1', 'Server2'
                        OperatingSystem
                    }

        $actual = Test-EventLogs $poShMonConfiguration -WarningAction SilentlyContinue
        
        $actual.NoIssuesFound | Should Be $false

        $actual.OutputValues.Count  | Should Be 2
        $actual.OutputValues[0].GroupName  | Should Be 'Server1'
        $actual.OutputValues[1].GroupName  | Should Be 'Server2'
    }
    It "Should group on EventID and Message" {

        Mock -CommandName Get-WmiObject -MockWith {
            $eventsCollection = @()

            $date = Get-Date

            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", $date, "Sample Message")
            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", $date.AddMinutes(-1), "Sample Message")
            $eventsCollection += [EventLogItemMock]::new(123, "Test App", "domain\user1", $date.AddMinutes(-2), "Another Sample Message")
            $eventsCollection += [EventLogItemMock]::new(456, "Test App", "domain\user1", $date.AddMinutes(-3), "Different Event Code")

            return $eventsCollection
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-EventLogs $poShMonConfiguration -WarningAction SilentlyContinue
        
        $actual.NoIssuesFound | Should Be $false

        $actual.OutputValues[0].GroupOutputValues.Count | Should Be 3
        $actual.OutputValues[0].GroupOutputValues[0].InstanceCount | Should Be 2
        $actual.OutputValues[0].GroupOutputValues[1].InstanceCount | Should Be 1
        $actual.OutputValues[0].GroupOutputValues[2].InstanceCount | Should Be 1
    }
}
