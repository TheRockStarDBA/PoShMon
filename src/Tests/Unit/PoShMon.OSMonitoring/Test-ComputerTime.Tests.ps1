$rootPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath ('..\..\..\') -Resolve
Remove-Module PoShMon -ErrorAction SilentlyContinue
Import-Module (Join-Path $rootPath -ChildPath "PoShMon.psd1") -Verbose

class ServerTimeMock {
    [string]$PSComputerName
    [datetime]$DateTime
    [int]$Year
    [int]$Month
    [int]$Day
    [int]$Hour
    [int]$Minute
    [int]$Second

    ServerTimeMock ([string]$NewPSComputerName, [datetime]$NewDateTime) {
        $this.PSComputerName = $NewPSComputerName;
        $this.DateTime = $NewDateTime
    }

    [datetime] ConvertToDateTime([string]$something) {
        return $this.DateTime
    }
}

Describe "Test-ComputerTime" {
    It "Should throw an exception if no OperatingSystem configuration is set" {
    
        $poShMonConfiguration = New-PoShMonConfiguration { }

        { Test-ComputerTime $poShMonConfiguration } | Should throw
    }

    It "Should return a matching output structure" {
    
        Mock -CommandName Get-WmiObject -MockWith {
            return [ServerTimeMock]::new('Server1', (Get-Date -Hour 10 -Minute 15))
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.Keys.Count | Should Be 5
        $actual.ContainsKey("NoIssuesFound") | Should Be $true
        $actual.ContainsKey("OutputHeaders") | Should Be $true
        $actual.ContainsKey("OutputValues") | Should Be $true
        $actual.ContainsKey("SectionHeader") | Should Be $true
        $actual.ContainsKey("ElapsedTime") | Should Be $true
        $headers = $actual.OutputHeaders
        $headers.Keys.Count | Should Be 2
        $values1 = $actual.OutputValues[0]
        $values1.Keys.Count | Should Be 3
    }

    It "Should warn on different server time (to local PoShMon machine)" {

        Mock -CommandName Get-WmiObject -MockWith {
            return @(
                [ServerTimeMock]::new('Server1', (Get-Date -Hour 10 -Minute 15).AddMinutes(-6))
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $false

        $actual.OutputValues.Highlight.Count | Should Be 1
        $actual.OutputValues.Highlight | Should Be "CurrentTime"
    }

    It "Should not warn on matching server times" {

        Mock -CommandName Get-WmiObject -MockWith {
            return @(
                [ServerTimeMock]::new('Server1', (Get-Date -Hour 10 -Minute 15))
                [ServerTimeMock]::new('Server2', (Get-Date -Hour 10 -Minute 15))
                [ServerTimeMock]::new('Server3', (Get-Date -Hour 10 -Minute 15))
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $true

        $actual.OutputValues.Highlight.Count | Should Be 0
    }

    It "Should not warn on server time differences within default threshold" {

        Mock -CommandName Get-WmiObject -MockWith {
            return @(
                [ServerTimeMock]::new('Server1', (Get-Date -Hour 10 -Minute 15))
                [ServerTimeMock]::new('Server2', (Get-Date -Hour 10 -Minute 15).AddMinutes(-1))
                [ServerTimeMock]::new('Server3', (Get-Date -Hour 10 -Minute 15))
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $true

        $actual.OutputValues.Highlight.Count | Should Be 0
    }

     It "Should warn on server times with differences above default threshold" {

        Mock -CommandName Get-WmiObject -MockWith {
            return @(
                [ServerTimeMock]::new('Server1', (Get-Date -Hour 10 -Minute 15))
                [ServerTimeMock]::new('Server2', (Get-Date -Hour 10 -Minute 15).AddMinutes(-3))
                [ServerTimeMock]::new('Server3', (Get-Date -Hour 10 -Minute 15))
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $false

        $actual.OutputValues.Highlight.Count | Should Be 3
        $actual.OutputValues.Highlight[0] | Should Be "CurrentTime"
    }

    It "Should not warn on server time differences within configured threshold" {

        Mock -CommandName Get-WmiObject -MockWith {
            return @(
                [ServerTimeMock]::new('Server1', (Get-Date -Hour 10 -Minute 15))
                [ServerTimeMock]::new('Server2', (Get-Date -Hour 10 -Minute 15))
                [ServerTimeMock]::new('Server3', (Get-Date -Hour 10 -Minute 15).AddMinutes(-27))
                [ServerTimeMock]::new('Server4', (Get-Date -Hour 10 -Minute 15))
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem -AllowedMinutesVarianceBetweenServerTimes 31
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $true

        $actual.OutputValues.Highlight.Count | Should Be 0
    }

     It "Should warn on server times with differences above configured threshold" {

        Mock -CommandName Get-WmiObject -MockWith {
            return @(
                [ServerTimeMock]::new('Server1', (Get-Date -Hour 10 -Minute 15))
                [ServerTimeMock]::new('Server2', (Get-Date -Hour 10 -Minute 15).AddMinutes(-3))
                [ServerTimeMock]::new('Server3', (Get-Date -Hour 10 -Minute 15))
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem -AllowedMinutesVarianceBetweenServerTimes 2
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $false

        $actual.OutputValues.Highlight.Count | Should Be 3
        $actual.OutputValues.Highlight[0] | Should Be "CurrentTime"
    }

     It "Should not warn on server times with differences within default threshold across hour boundaries" {

        Mock -CommandName Get-WmiObject -MockWith {
            return @(
                [ServerTimeMock]::new('Server1', (Get-Date -Hour 11 -Minute 01))
                [ServerTimeMock]::new('Server2', (Get-Date -Hour 10 -Minute 59))
                [ServerTimeMock]::new('Server3', (Get-Date -Hour 11 -Minute 01))
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem -AllowedMinutesVarianceBetweenServerTimes 3
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $true
    }

     It "Should not warn on server times with differences within default threshold across day boundaries" {

        Mock -CommandName Get-WmiObject -MockWith {
            return @(
                [ServerTimeMock]::new('Server1', (Get-Date -Hour 00 -Minute 01))
                [ServerTimeMock]::new('Server2', (Get-Date -Hour 23 -Minute 59).AddDays(-1))
                [ServerTimeMock]::new('Server3', (Get-Date -Hour 00 -Minute 01))
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                        General -ServerNames 'Server1'
                        OperatingSystem -AllowedMinutesVarianceBetweenServerTimes 3
                    }

        $actual = Test-ComputerTime $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $true
    }
}