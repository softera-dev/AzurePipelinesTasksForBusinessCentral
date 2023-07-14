@{
    IncludeDefaultRules = $true

    Rules = @{
        'PSUseBOMForUnicodeEncodedFile' = @{
            Enable = $false
        }
        'PSAlignAssignmentStatement' = @{
            Enable = $false
        }
        'PSAvoidLongLines' = @{
            Enable = $true
        }
        'PSAvoidSemicolonsAsLineTerminators' = @{
            Enable = $true
        }
        'PSAvoidUsingDoubleQuotesForConstantString' = @{
            Enable = $true
        }
        'PSPlaceCloseBrace' = @{
            Enable = $true
        }
        'PSPlaceOpenBrace' = @{
            Enable = $true
        }
        <#
        'PSUseCompatibleCommands' = @{
            Enable = $true
            TargetProfiles = @(
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
                'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core'
            )
        }
        'PSUseCompatibleSyntax' = @{
            Enable = $true
            TargetProfiles = @(
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
                'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core'
            )
        }
        'PSUseCompatibleTypes' = @{
            Enable = $true
            TargetProfiles = @(
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'
                'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core'
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
                'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core'
            )
        }
        #>
        'PSUseConsistentIndentation' = @{
            Enable = $true
        }
        'PSUseConsistentWhitespace' = @{
            Enable = $true
        }
        'PSUseCorrectCasing' = @{
            Enable = $true
        }
        'PSPSUseConsistentIndentation' = @{
            Enable = $true
            IndentationSize = 4
            Kind = 'space'
        }
    }
}
