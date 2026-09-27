BeforeAll {
    $script:RepositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $script:RepositoryRoot 'scripts/Lab.Core.psm1') -Force -DisableNameChecking
    function New-TestLabConfiguration {
        @{
            lab_id='demo01';subscription_id='11111111-1111-1111-1111-111111111111';tenant_id='22222222-2222-2222-2222-222222222222';location='westeurope'
            foundation_resource_group_name='rg-demo01-foundation';workload_resource_group_name='rg-demo01-workload';pool_name='mdp-demo01'
            azure_devops_organization_url='https://dev.azure.com/example';azure_devops_project_name='lab'
            agent_identity_client_id='33333333-3333-3333-3333-333333333333';agent_identity_principal_id='44444444-4444-4444-4444-444444444444';operator_principal_id='55555555-5555-5555-5555-555555555555'
            state_storage_account_name='stdemo01';state_container_name='tfstate';state_key='workload/demo01.tfstate'
            key_vault_name='kv-demo01';key_vault_uri='https://kv-demo01.vault.azure.net/';blob_private_ip='10.60.1.4';vault_private_ip='10.60.1.5'
            firewall_resource_id='/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-demo01-foundation/providers/Microsoft.Network/azureFirewalls/fw-demo01'
            log_analytics_workspace_id='66666666-6666-6666-6666-666666666666';bootstrap_secret_write_enabled=$false;workload_vnet_cidr='10.70.0.0/24'
        }
    }
}

Describe 'Exported configuration boundary' {
    BeforeEach {
        $script:config = New-TestLabConfiguration
        $script:configPath = Join-Path $TestDrive 'config.json'
    }
    It 'accepts the expected flat output contract' {
        $config | ConvertTo-Json | Set-Content $configPath
        (Get-LabConfiguration $configPath).operator_principal_id | Should -Be $config.operator_principal_id
    }
    It 'rejects a mismatched firewall subscription' {
        $config.firewall_resource_id = $config.firewall_resource_id.Replace($config.subscription_id,'99999999-9999-9999-9999-999999999999')
        $config | ConvertTo-Json | Set-Content $configPath
        { Get-LabConfiguration $configPath } | Should -Throw '*Firewall target*'
    }
    It 'rejects a vault URI that points elsewhere' {
        $config.key_vault_uri = 'https://elsewhere.example/'
        $config | ConvertTo-Json | Set-Content $configPath
        { Get-LabConfiguration $configPath } | Should -Throw '*URI*'
    }
    It 'rejects a path-like lab ID' {
        $config.lab_id = '../other'
        $config | ConvertTo-Json | Set-Content $configPath
        { Get-LabConfiguration $configPath } | Should -Throw '*LabId*'
    }
    It 'requires a separate workload resource group' {
        $config.workload_resource_group_name = $config.foundation_resource_group_name
        $config | ConvertTo-Json | Set-Content $configPath
        { Get-LabConfiguration $configPath } | Should -Throw '*must differ*'
    }
    It 'rejects stringly typed bootstrap flags' {
        $config.bootstrap_secret_write_enabled = 'false'
        $config | ConvertTo-Json | Set-Content $configPath
        { Get-LabConfiguration $configPath } | Should -Throw '*JSON booleans*'
    }
    It 'requires an actual operator principal' {
        $config.Remove('operator_principal_id')
        $config | ConvertTo-Json | Set-Content $configPath
        { Get-LabConfiguration $configPath } | Should -Throw '*operator_principal_id*'
    }
}

Describe 'Native invocation without secret output' {
    It 'captures stdout without splitting an argument that contains spaces' {
        $result = Invoke-LabNative pwsh @('-NoProfile','-NonInteractive','-Command','Write-Output "two words"; exit 0')
        $result.ExitCode | Should -Be 0
        $result.Output.Trim() | Should -Be 'two words'
    }
    It 'does not expose stderr or arguments in an unexpected-failure exception' {
        try {
            Invoke-LabNative pwsh @('-NoProfile','-NonInteractive','-Command','[Console]::Error.WriteLine("test-secret-marker"); exit 7')
            throw 'Expected native failure.'
        } catch {
            $_.Exception.Message | Should -Match 'exit 7'
            $_.Exception.Message | Should -Not -Match 'test-secret-marker'
        }
    }
    It 'returns an explicitly expected failure for negative assertions' {
        $result = Invoke-LabNative pwsh @('-NoProfile','-NonInteractive','-Command','exit 3') -AllowedExitCodes @(0,3)
        $result.ExitCode | Should -Be 3
    }
    It 'cannot turn a missing executable into a stale successful exit code' {
        $global:LASTEXITCODE = 0
        { Invoke-LabNative 'this-command-does-not-exist-azure-lab-test' } | Should -Throw
    }
}

Describe 'Azure account and cleanup guards (mocked only)' {
    BeforeEach { $script:config = [pscustomobject](New-TestLabConfiguration) }
    It 'rejects an unintended subscription before mutation' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=0;Output='{"id":"99999999-9999-9999-9999-999999999999","tenantId":"22222222-2222-2222-2222-222222222222"}'} }
        { Assert-LabSubscription $config } | Should -Throw '*differs*'
    }
    It 'refuses foundation cleanup while workload resources exist' {
        Mock Assert-LabOwnership -ModuleName Lab.Core {}
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=0;Output='[{"id":"/sample/resource"}]'} }
        { Assert-LabWorkloadEmpty $config } | Should -Throw '*not empty*'
    }
    It 'accepts an empty owned workload group' {
        Mock Assert-LabOwnership -ModuleName Lab.Core {}
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=0;Output='[]'} }
        { Assert-LabWorkloadEmpty $config } | Should -Not -Throw
    }
    It 'rejects a group outside exported targets before any Azure call' {
        Mock Invoke-LabNative -ModuleName Lab.Core { throw 'Unexpected Azure invocation.' }
        { Assert-LabOwnership $config 'rg-unrelated' } | Should -Throw '*outside*'
        Should -Invoke Invoke-LabNative -ModuleName Lab.Core -Times 0
    }
}

Describe 'Preview and explicit destruction boundary' {
    It 'previews foundation plan without a local varfile, Terraform or Azure login' {
        $text = & (Join-Path $RepositoryRoot 'scripts/Invoke-Lab.ps1') -Action Plan -LabId demo01 -SubscriptionId 11111111-1111-1111-1111-111111111111 -VarFile (Join-Path $TestDrive 'missing.tfvars')
        ($text -join ' ') | Should -Match 'No Azure or Terraform commands executed'
    }
    It 'requires the exact approved DESTROY phrase before account access' {
        { & (Join-Path $RepositoryRoot 'scripts/Invoke-Lab.ps1') -Action Destroy -LabId demo01 -SubscriptionId 11111111-1111-1111-1111-111111111111 -Execute -Confirmation 'destroy:demo01' } | Should -Throw '*DESTROY demo01*'
    }
    It 'previews private connectivity checks without DNS or Azure calls' {
        $path = Join-Path $TestDrive 'private.json'
        New-TestLabConfiguration | ConvertTo-Json | Set-Content $path
        $text = & (Join-Path $RepositoryRoot 'scripts/Test-LabPrivateAccess.ps1') -ConfigPath $path
        ($text -join ' ') | Should -Match 'Preview'
    }
    It 'previews the state locking fixture without starting Terraform' {
        $path = Join-Path $TestDrive 'locking.json'
        New-TestLabConfiguration | ConvertTo-Json | Set-Content $path
        $text = & (Join-Path $RepositoryRoot 'scripts/Test-LabStateLock.ps1') -ConfigPath $path
        ($text -join ' ') | Should -Match 'Preview'
    }
}

Describe 'Operator authentication boundaries (mocked only)' {
    BeforeEach {
        $script:config = [pscustomobject](New-TestLabConfiguration)
        Mock Invoke-LabNative -ModuleName Lab.Core {
            if ($Arguments[1] -eq 'show') {
                [pscustomobject]@{ExitCode=0;Output='{"id":"11111111-1111-1111-1111-111111111111","tenantId":"22222222-2222-2222-2222-222222222222"}'}
            } else {
                $claims = '{"oid":"55555555-5555-5555-5555-555555555555","tid":"22222222-2222-2222-2222-222222222222"}'
                $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claims)).TrimEnd('=').Replace('+','-').Replace('/','_')
                [pscustomobject]@{ExitCode=0;Output=(@{accessToken="test.$payload.signature"} | ConvertTo-Json)}
            }
        }
    }
    It 'accepts the configured operator without emitting its token' {
        $output = @(Assert-LabOperator $config)
        $output.Count | Should -Be 0
    }
    It 'rejects another user even in the correct subscription and tenant' {
        $config.operator_principal_id = '77777777-7777-7777-7777-777777777777'
        { Assert-LabOperator $config } | Should -Throw '*operator_principal_id*'
    }
    It 'clears inherited credential and Terraform argument overrides for CLI authentication' {
        $snapshot = @{}
        foreach ($key in @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -like 'ARM_*' -or $_ -like 'TF_*' })) { $snapshot[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
        try {
            $env:ARM_CLIENT_SECRET = 'test-only-value'
            $env:ARM_ACCESS_KEY = 'test-only-key'
            $env:TF_CLI_ARGS_plan = '-lock=false'
            $env:TF_LOG = 'TRACE'
            Set-LabCliEnvironment $config
            $env:ARM_USE_CLI | Should -Be 'true'
            $env:ARM_USE_OIDC | Should -Be 'false'
            $env:ARM_CLIENT_SECRET | Should -BeNullOrEmpty
            $env:ARM_ACCESS_KEY | Should -BeNullOrEmpty
            $env:TF_CLI_ARGS_plan | Should -BeNullOrEmpty
            $env:TF_LOG | Should -BeNullOrEmpty
        } finally {
            foreach ($key in @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -like 'ARM_*' -or $_ -like 'TF_*' })) { [Environment]::SetEnvironmentVariable($key,$null,'Process') }
            foreach ($key in $snapshot.Keys) { [Environment]::SetEnvironmentVariable($key,$snapshot[$key],'Process') }
        }
    }
}

Describe 'MDP capacity preflight from offline response fixtures' {
    It 'accepts an unrestricted SKU with two or more available family cores' {
        $fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/capacity-sufficient.json') -Raw | ConvertFrom-Json
        $result = Assert-LabMdpCapacity -SkuItems $fixture.skus -UsageItems $fixture.usages -Location westeurope
        $result.AvailableCores | Should -Be 4
        $result.RequiredCores | Should -Be 2
    }
    It 'fails when the quota family is missing instead of treating absence as unlimited' {
        $fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/capacity-missing-quota.json') -Raw | ConvertFrom-Json
        { Assert-LabMdpCapacity -SkuItems $fixture.skus -UsageItems $fixture.usages -Location westeurope } | Should -Throw '*quota family*missing*'
    }
    It 'fails when remaining quota cannot fit one two-core agent' {
        $fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/capacity-full.json') -Raw | ConvertFrom-Json
        { Assert-LabMdpCapacity -SkuItems $fixture.skus -UsageItems $fixture.usages -Location westeurope } | Should -Throw '*requires 2*'
    }
    It 'fails for a restricted SKU even when quota is sufficient' {
        $fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures/capacity-sufficient.json') -Raw | ConvertFrom-Json
        $fixture.skus[0].properties.restrictions = @(@{reasonCode='NotAvailableForSubscription'})
        { Assert-LabMdpCapacity -SkuItems $fixture.skus -UsageItems $fixture.usages -Location westeurope } | Should -Throw '*restrictions*'
    }
    It 'follows ARM pagination without losing items' {
        Mock Invoke-LabNative -ModuleName Lab.Core {
            if ($Arguments[4] -like '*page=2') { [pscustomobject]@{ExitCode=0;Output='{"value":[{"name":"second"}],"nextLink":null}'} }
            else { [pscustomobject]@{ExitCode=0;Output='{"value":[{"name":"first"}],"nextLink":"https://management.azure.com/subscriptions/test/items?page=2"}'} }
        }
        $items = @(Get-LabArmCollection -Uri 'https://management.azure.com/subscriptions/test/items?page=1')
        $items.Count | Should -Be 2
        $items[1].name | Should -Be 'second'
        Should -Invoke Invoke-LabNative -ModuleName Lab.Core -Times 2
    }
    It 'rejects pagination to a different host before sending credentials' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=0;Output='{"value":[],"nextLink":"https://other.example/items"}'} }
        { Get-LabArmCollection -Uri 'https://management.azure.com/subscriptions/test/items' } | Should -Throw '*unexpected host*'
        Should -Invoke Invoke-LabNative -ModuleName Lab.Core -Times 1
    }
}

Describe 'Public probe separates network denial from credentials and private access' {
    BeforeEach {
        $script:config = [pscustomobject](New-TestLabConfiguration)
        $script:evidence = @{
            lab_id=$config.lab_id;subscription_id=$config.subscription_id;tenant_id=$config.tenant_id
            operator_principal_id=$config.operator_principal_id;state_storage_account_name=$config.state_storage_account_name
            state_container_name=$config.state_container_name;key_vault_name=$config.key_vault_name
            timestamp_utc=[DateTime]::UtcNow.ToString('o')
            checks=@{blob_read='passed';secret_read='passed';'stdemo01.blob.core.windows.net'=@('10.60.1.4');'kv-demo01.vault.azure.net'=@('10.60.1.5')}
        }
    }
    It 'rejects uppercase lab identifiers' { { Assert-LabId 'Demo01' } | Should -Throw '*lowercase*' }
    It 'accepts fresh private positive evidence bound to this identity and endpoints' { { Assert-LabPrivateEvidence $config $evidence } | Should -Not -Throw }
    It 'rejects evidence from another operator' {
        $evidence.operator_principal_id = '77777777-7777-7777-7777-777777777777'
        { Assert-LabPrivateEvidence $config $evidence } | Should -Throw '*operator_principal_id*'
    }
    It 'rejects evidence from a different vault' {
        $evidence.key_vault_name = 'kv-other'
        { Assert-LabPrivateEvidence $config $evidence } | Should -Throw '*key_vault_name*'
    }
    It 'rejects old evidence' {
        $evidence.timestamp_utc = [DateTime]::UtcNow.AddHours(-25).ToString('o')
        { Assert-LabPrivateEvidence $config $evidence } | Should -Throw '*24 hours*'
    }
    It 'rejects DNS-only or skipped-secret private tests' {
        $evidence.checks.Remove('secret_read')
        { Assert-LabPrivateEvidence $config $evidence } | Should -Throw '*successful authenticated*'
    }
    It 'rejects evidence with an incorrect private DNS result' {
        $evidence.checks['stdemo01.blob.core.windows.net'] = @('10.60.9.9')
        { Assert-LabPrivateEvidence $config $evidence } | Should -Throw '*DNS result*'
    }
    It 'accepts public IPv4 DNS answers' {
        { Assert-LabPublicAddresses -HostName example.blob.core.windows.net -Addresses @('20.60.1.2') } | Should -Not -Throw
    }
    It 'rejects mixed public and private DNS answers' {
        { Assert-LabPublicAddresses -HostName example.blob.core.windows.net -Addresses @('20.60.1.2','10.60.1.4') } | Should -Throw '*public IPv4 addresses*'
    }
    It 'rejects loopback, link-local and IPv6 addresses' {
        { Assert-LabPublicAddresses -HostName example.vault.azure.net -Addresses @('::1') } | Should -Throw '*public IPv4 addresses*'
        { Assert-LabPublicAddresses -HostName example.vault.azure.net -Addresses @('169.254.1.1') } | Should -Throw '*public IPv4 addresses*'
    }
    It 'accepts the expected network-specific service error codes' {
        { Assert-LabNetworkDenial -Service Blob -StatusCode 403 -ErrorCode AuthorizationFailure } | Should -Not -Throw
        { Assert-LabNetworkDenial -Service KeyVault -StatusCode 403 -ErrorCode Forbidden -InnerErrorCode ForbiddenByConnection } | Should -Not -Throw
    }
    It 'does not treat RBAC or authentication failures as network-denial evidence' {
        { Assert-LabNetworkDenial -Service Blob -StatusCode 403 -ErrorCode AuthorizationPermissionMismatch } | Should -Throw '*RBAC*'
        { Assert-LabNetworkDenial -Service KeyVault -StatusCode 403 -ErrorCode Forbidden -InnerErrorCode ForbiddenByRbac } | Should -Throw '*RBAC*'
        { Assert-LabNetworkDenial -Service KeyVault -StatusCode 401 -ErrorCode Unauthorized } | Should -Throw '*HTTP 401*'
    }
    It 'fails when the public read unexpectedly succeeds' {
        { Assert-LabNetworkDenial -Service Blob -StatusCode 200 } | Should -Throw '*HTTP 200*'
    }
    It 'previews without reading evidence or contacting any network' {
        $path = Join-Path $TestDrive 'public.json'
        $config | ConvertTo-Json | Set-Content $path
        $text = & (Join-Path $RepositoryRoot 'scripts/Test-LabPublicAccess.ps1') -ConfigPath $path
        ($text -join ' ') | Should -Match 'Preview'
    }
}

Describe 'Exact soft-deleted lab vault cleanup reporting (mocked only)' {
    BeforeEach { $script:config = [pscustomobject](New-TestLabConfiguration) }
    It 'reports retained vault dates separately from active resource cleanup' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=0;Output='{"name":"kv-demo01","properties":{"vaultId":"/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-demo01-foundation/providers/Microsoft.KeyVault/vaults/kv-demo01","deletionDate":"2026-09-27T00:00:00Z","scheduledPurgeDate":"2026-10-04T00:00:00Z"}}'} }
        $result = Get-LabDeletedVault $config
        $result.Status | Should -Be RETAINED
        ([string]$result.ScheduledPurgeDate) | Should -Not -BeNullOrEmpty
        Should -Invoke Invoke-LabNative -ModuleName Lab.Core -Times 1 -ParameterFilter { $Arguments[1] -eq 'show-deleted' -and $Arguments[3] -eq 'kv-demo01' }
    }
    It 'reports exact resource-not-found as absent' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=1;Output='(ResourceNotFound) Deleted vault record not found.'} }
        (Get-LabDeletedVault $config).Status | Should -Be ABSENT
    }
    It 'never treats authorization failure as absence' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=1;Output='(AuthorizationFailed) No permission to read deleted vault.'} }
        { Get-LabDeletedVault $config } | Should -Throw '*incomplete*'
    }
    It 'rejects a retained vault record from another resource group' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=0;Output='{"name":"kv-demo01","properties":{"vaultId":"/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-other/providers/Microsoft.KeyVault/vaults/kv-demo01","deletionDate":"2026-09-27T00:00:00Z","scheduledPurgeDate":"2026-10-04T00:00:00Z"}}'} }
        { Get-LabDeletedVault $config } | Should -Throw '*exact exported*'
    }
}


Describe 'Additional negative-probe refusal cases' {
    It 'refuses transport failures without an HTTP service denial' {
        { Assert-LabNetworkDenial -Service Blob -StatusCode 0 } | Should -Throw '*HTTP 0*'
        { Assert-LabNetworkDenial -Service KeyVault -StatusCode 504 } | Should -Throw '*HTTP 504*'
    }
    It 'conservatively refuses IPv6 even when it appears globally routable' {
        { Assert-LabPublicAddresses -HostName example.vault.azure.net -Addresses @('2603:1030:7::1') } | Should -Throw '*IPv6*'
    }
    It 'refuses representative special-purpose IPv4 ranges' {
        foreach ($address in @('100.64.1.1','172.20.1.1','192.0.2.1','192.88.99.1','198.18.1.1','198.51.100.1','203.0.113.1','224.1.1.1','240.1.1.1')) {
            { Assert-LabPublicAddresses -HostName example.vault.azure.net -Addresses @($address) } | Should -Throw '*public IPv4*'
        }
    }
}

Describe 'Egress CLI dependencies are inspected without installation' {
    It 'accepts an already installed extension with the exact requested name' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=0;Output='log-analytics'} }
        Test-LabCliExtensionInstalled -Name log-analytics | Should -BeTrue
        Should -Invoke Invoke-LabNative -ModuleName Lab.Core -Times 1 -ParameterFilter { $Arguments[0] -eq 'extension' -and $Arguments[1] -eq 'show' -and $Arguments[3] -eq 'log-analytics' }
    }
    It 'reports a missing extension without attempting installation' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=1;Output='The extension azure-firewall is not installed.'} }
        Test-LabCliExtensionInstalled -Name azure-firewall | Should -BeFalse
        Should -Invoke Invoke-LabNative -ModuleName Lab.Core -Times 1 -ParameterFilter { $Arguments[0] -eq 'extension' -and $Arguments[1] -eq 'show' }
        Should -Invoke Invoke-LabNative -ModuleName Lab.Core -Times 0 -ParameterFilter { $Arguments -contains 'add' }
    }
    It 'does not treat an uninspectable extension as available' {
        Mock Invoke-LabNative -ModuleName Lab.Core { [pscustomobject]@{ExitCode=2;Output='local CLI inspection failed'} }
        Test-LabCliExtensionInstalled -Name log-analytics | Should -BeFalse
    }
}
