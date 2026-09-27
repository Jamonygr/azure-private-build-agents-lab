BeforeAll {
    $script:Repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $script:WorkloadScript = Join-Path $script:Repository 'scripts/Invoke-Workload.ps1'
    # Preview loads the pure saved-plan guard functions without contacting Azure.
    . $script:WorkloadScript -Action Plan -LabId 'testlab' -SubscriptionId '11111111-1111-1111-1111-111111111111' | Out-Null
}

Describe 'Reviewed workload plan integrity' {
    BeforeEach {
        $script:PlanPath = Join-Path $TestDrive 'workload.tfplan'
        $script:ManifestPath = Join-Path $TestDrive 'workload-plan.json'
        [IO.File]::WriteAllBytes($script:PlanPath, [byte[]]@(1, 3, 7, 9))
        $script:GuardArguments = @{
            PlanPath = $script:PlanPath
            ManifestPath = $script:ManifestPath
            ExpectedFingerprint = 'inputs-v1'
            ExpectedLabId = 'testlab'
            ExpectedSubscriptionId = '11111111-1111-1111-1111-111111111111'
            ExpectedStateKey = 'workload/testlab.tfstate'
            ExpectedCommit = 'commit-one'
        }
        @{
            lab_id = 'testlab'
            subscription_id = '11111111-1111-1111-1111-111111111111'
            state_key = 'workload/testlab.tfstate'
            source_commit = 'commit-one'
            input_hash = 'inputs-v1'
            plan_sha256 = (Get-FileHash -LiteralPath $script:PlanPath -Algorithm SHA256).Hash
            destroy = $false
        } | ConvertTo-Json | Set-Content -LiteralPath $script:ManifestPath
    }

    It 'accepts an unchanged reviewed plan for its exact target' {
        { Assert-WorkloadSavedPlan @script:GuardArguments } | Should -Not -Throw
    }

    It 'rejects a plan modified after review' {
        [IO.File]::WriteAllBytes($script:PlanPath, [byte[]]@(2, 3, 7, 9))
        { Assert-WorkloadSavedPlan @script:GuardArguments } | Should -Throw '*changed*'
    }

    It 'rejects deployment after configuration or Terraform source changes' {
        $script:GuardArguments.ExpectedFingerprint = 'inputs-v2'
        { Assert-WorkloadSavedPlan @script:GuardArguments } | Should -Throw '*changed*'
    }

    It 'rejects a plan from a different subscription' {
        $script:GuardArguments.ExpectedSubscriptionId = '22222222-2222-2222-2222-222222222222'
        { Assert-WorkloadSavedPlan @script:GuardArguments } | Should -Throw '*changed*'
    }

    It 'rejects a plan targeting another remote-state key' {
        $script:GuardArguments.ExpectedStateKey = 'workload/otherlab.tfstate'
        { Assert-WorkloadSavedPlan @script:GuardArguments } | Should -Throw '*changed*'
    }

    It 'rejects a plan from another source commit' {
        $script:GuardArguments.ExpectedCommit = 'commit-two'
        { Assert-WorkloadSavedPlan @script:GuardArguments } | Should -Throw '*changed*'
    }

    It 'does not accept a deployment plan as a destruction plan' {
        { Assert-WorkloadSavedPlan @script:GuardArguments -Destroy $true } | Should -Throw '*changed*'
    }

    It 'requires the manifest to survive alongside its plan' {
        Remove-Item -LiteralPath $script:ManifestPath
        { Assert-WorkloadSavedPlan @script:GuardArguments } | Should -Throw '*reviewed saved plan*'
    }
}

Describe 'Workload input changes' {
    BeforeEach {
        $script:InputsDirectory = Join-Path $TestDrive ('inputs-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:InputsDirectory | Out-Null
        Set-Content -LiteralPath (Join-Path $script:InputsDirectory 'main.tf') -Value '# original infrastructure'
        Set-Content -LiteralPath (Join-Path $script:InputsDirectory '.terraform.lock.hcl') -Value '# provider lock'
        $script:ConfigurationPath = Join-Path $TestDrive 'lab-config.json'
        Set-Content -LiteralPath $script:ConfigurationPath -Value '{"lab_id":"testlab"}'
    }

    It 'detects changes within nested local module source' {
        $moduleDirectory = Join-Path $script:InputsDirectory 'modules/networking'
        New-Item -ItemType Directory -Path $moduleDirectory -Force | Out-Null
        $modulePath = Join-Path $moduleDirectory 'main.tf'
        Set-Content -LiteralPath $modulePath -Value '# before review'
        $before = Get-WorkloadFingerprint -Directory $script:InputsDirectory -ConfigurationPath $script:ConfigurationPath
        Set-Content -LiteralPath $modulePath -Value '# after review'
        $after = Get-WorkloadFingerprint -Directory $script:InputsDirectory -ConfigurationPath $script:ConfigurationPath
        $after | Should -Not -Be $before
    }

    It 'detects a changed exported configuration' {
        $before = Get-WorkloadFingerprint -Directory $script:InputsDirectory -ConfigurationPath $script:ConfigurationPath
        Set-Content -LiteralPath $script:ConfigurationPath -Value '{"lab_id":"otherlab"}'
        (Get-WorkloadFingerprint -Directory $script:InputsDirectory -ConfigurationPath $script:ConfigurationPath) | Should -Not -Be $before
    }

    It 'refuses an absent provider lock' {
        Remove-Item -LiteralPath (Join-Path $script:InputsDirectory '.terraform.lock.hcl')
        { Get-WorkloadFingerprint -Directory $script:InputsDirectory -ConfigurationPath $script:ConfigurationPath } | Should -Throw '*provider lock*'
    }
}

Describe 'Explicit execution and destruction confirmation' {
    It 'previews without needing credentials, config, or Terraform' {
        $result = & $script:WorkloadScript -Action Apply -LabId 'testlab' -SubscriptionId '11111111-1111-1111-1111-111111111111' -ConfigPath (Join-Path $TestDrive 'absent.json')
        $result | Should -Match 'No Azure or Terraform commands executed'
    }

    It 'rejects an inexact destructive confirmation before reading configuration' {
        { & $script:WorkloadScript -Action Destroy -LabId 'testlab' -SubscriptionId '11111111-1111-1111-1111-111111111111' -ConfigPath (Join-Path $TestDrive 'absent.json') -Execute -Confirmation 'destroy testlab' } | Should -Throw '*DESTROY testlab*'
    }
}
