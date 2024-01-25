#Entrez votre clé API
$APIKey = read-host -Prompt "Entrez votre clé API"

# Demande du nombre d'appels par minute à l'API
$validResponses = @("10", "50", "100", "500")
$apiCallsPerMinute = ""
while ($validResponses -notcontains $apiCallsPerMinute) {
    $apiCallsPerMinute = Read-Host -Prompt "Combien d'appels par minute souhaitez-vous faire à l'API ? (10, 50, 100, 500)"
}

# Calcul du délai en secondes en fonction du nombre d'appels à l'API souhaité par minute
$delaySeconds = 60 / [int]$apiCallsPerMinute

$emailListPath = Read-Host -Prompt "Entrez le chemin du fichier txt contenant votre liste de mails (séparés par une nouvelle ligne)"
$reportFolderPath = Read-Host -Prompt "Entrez le chemin du dossier dans lequel les rapports seront stockés (avec le / à la fin)"

# Vérification de l'installation du module HaveIBeenPwned
$response = Get-InstalledModule -Name HaveIBeenPwned

if ($response -eq $null)
{
    Write-Host "Installation du module HaveIBeenPwned" -BackgroundColor Yellow
    Install-Module -Name HaveIBeenPwned -Force
}

# Enumération des e-mails du fichier txt dans un tableau
$emailListArray = [System.Collections.ArrayList]@()
foreach ($line in [System.IO.File]::ReadLines($($emailListPath)))
{
    $emailListArray.Add($line) > $null
}

if ($emailListArray.Count -eq 0)
{
    Write-Host "Aucun e-mail n'a été trouvé, vérifiez la source et réessayez !" -BackgroundColor Red
    Break
}
else
{
    Write-Host "Trouvé $($emailListArray.Count) e-mails dans $($emailListPath)" -BackgroundColor Yellow
}

$pwnedUsersCount = 0

# Tableaux pour stocker les e-mails compromis, les violations de données et les pastes
$PwnedEmailsArray = [System.Collections.ArrayList]@()
$PwnedEmailBreachsArray = [System.Collections.ArrayList]@()
$PwnedEmailPastesArray = [System.Collections.ArrayList]@()

# Parcours de chaque e-mail
for ($i = 0; $i -lt $emailListArray.Count; $i++)
{
    $pwnedCounter = 0

    Write-Host "[$($i)/$($emailListArray.Count)] Vérification de $($emailListArray[$i])"
    $CheckEmailPastes = ""
    $CheckEmailPastes = Get-PwnedPasteAccount -EmailAddress $($emailListArray[$i]) -apiKey $APIKey
    $EmailPastesCount = $CheckEmailPastes.Source | Measure-Object

    if ($CheckEmailPastes.Status -eq "Good")
    {
        Write-Host "[+] Introuvable sur Pastebin, Pastie, Slexy, Ghostbin, QuickLeak, JustPaste, AdHocUrl, PermanentOptOut, OptOut"
    }
    else
    {
        $EmailPasteDetailsArray = [System.Collections.ArrayList]@()
        for ($ii = 0; $ii -lt $EmailPastesCount.Count; $ii++)
        {
            Write-Host "[!] E-mail trouvé sur Pastebin, Pastie, Slexy, Ghostbin, QuickLeak, JustPaste, AdHocUrl, PermanentOptOut, OptOut" -BackgroundColor Red
            $PasteDetails = "" | Select-Object Email, Id, Source, Title, Date
            $PasteDetails.Email = $emailListArray[$i]
            $PasteDetails.Id = $CheckEmailPastes[$ii].Id 
            $PasteDetails.Source = $CheckEmailPastes[$ii].Source 
            $PasteDetails.Title = $CheckEmailPastes[$ii].Title
            $PasteDetails.Date = $CheckEmailPastes[$ii].Date
            $EmailPasteDetailsArray += $PasteDetails
            $pwnedCounter++
        }
        # Ajout de tous les résultats dans un tableau
        $PwnedEmailPastesArray.Add($EmailPasteDetailsArray) > $null
    }

    Start-Sleep 2

    $CheckEmailBreaches = ""
    $CheckEmailBreaches = Get-PwnedAccount -EmailAddress $($emailListArray[$i]) -apiKey $APIKey
    $EmailBreachCount = $CheckEmailBreaches.Name | Measure-Object

    if ($CheckEmailBreaches.Status -eq "Good")
    {
        Write-Host "[+] Introuvable dans les bases de données connues"
    }
    else
    {
         for ($ii = 0; $ii -lt $EmailBreachCount.Count; $ii++)
         {
            $BreachDetails = "" | Select-Object Email, Title, Domain, BreachDate, DataClasses, ContainsPassword, IsVerified, IsSpamList, IsMalware
            $BreachDetails.Email = $emailListArray[$i]
            $BreachDetails.Title = $CheckEmailBreaches[$ii].Title
            $BreachDetails.Domain = $CheckEmailBreaches[$ii].Domain
            $BreachDetails.BreachDate = $CheckEmailBreaches[$ii].BreachDate
            $BreachDetails.DataClasses =  [String]::Join(" - ", $CheckEmailBreaches[$ii].DataClasses)
            $BreachDetails.IsVerified = $CheckEmailBreaches[$ii].IsVerified
            $BreachDetails.IsSpamList = $CheckEmailBreaches[$ii].IsSpamList
            $BreachDetails.IsMalware = $CheckEmailBreaches[$ii].IsMalware
            #$BreachDetails.Description = $CheckEmailBreaches[$ii].Description 
            if ($CheckEmailBreaches[$ii].DataClasses -contains "Passwords")
            {
                $BreachDetails.ContainsPassword = "True"
                Write-Host "[!] E-mail trouvé dans une base de données - il contient le mot de passe" -BackgroundColor Red
            }
            else
            {
                $BreachDetails.ContainsPassword = "False"
                Write-Host "[!] E-mail trouvé dans une base de données" -BackgroundColor Red
            }
            $PwnedEmailBreachsArray += $BreachDetails
            $pwnedCounter++
         }
    }

    Start-Sleep 2

    # Si l'utilisateur est compromis, le script l'ajoute à la liste des compromis
    if ($pwnedCounter -gt 0)
    {
        $pwnedEmailsRanked = "" | Select-Object Email, Score
        $pwnedEmailsRanked.Email = $emailListArray[$i]
        $pwnedEmailsRanked.Score = $pwnedCounter
        $PwnedEmailsArray += $pwnedEmailsRanked
        $pwnedUsersCount++
    }

    Start-Sleep $delaySeconds
}

# Affichage des résultats finaux
Write-Host "-----------------------------------------------------------------------"
Write-Host "Rapport de recherche de compromission des e-mails"
Write-Host "-----------------------------------------------------------------------"
Write-Host ""
Write-Host "Nombre total d'e-mails vérifiés : $($emailListArray.Count)"
Write-Host "Nombre d'utilisateurs compromis : $($pwnedUsersCount)"
Write-Host ""

# Enregistrement des résultats dans des fichiers CSV
$PwnedEmailsArray | Export-Csv -Path ($reportFolderPath + "pwned_emails.csv") -NoTypeInformation
$PwnedEmailBreachsArray | Export-Csv -Path ($reportFolderPath + "pwned_breaches.csv") -NoTypeInformation
$PwnedEmailPastesArray | Export-Csv -Path ($reportFolderPath + "pwned_pastes.csv") -NoTypeInformation

Write-Host "Les résultats ont été enregistrés dans les fichiers CSV suivants :"
Write-Host "- $($reportFolderPath)pwned_emails.csv"
Write-Host "- $($reportFolderPath)pwned_breaches.csv"
Write-Host "- $($reportFolderPath)pwned_pastes.csv"

Write-Host ""
Write-Host "Terminé !"