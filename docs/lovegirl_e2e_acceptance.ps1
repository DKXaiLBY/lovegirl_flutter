param(
  [string]$BaseUrl = "http://47.121.119.191:3001",
  [string]$Prefix = ("E2E_" + (Get-Date -Format "yyyyMMddHHmmss")),
  [string]$Password = "E2ePass123!",
  [string]$BoyUsername = "",
  [string]$BoyPassword = "",
  [string]$GirlUsername = "",
  [string]$GirlPassword = "",
  [int]$TimeoutSec = 20,
  [switch]$SkipWrites,
  [switch]$UseExistingAccounts,
  [switch]$PreserveCouple,
  [switch]$AllowExistingCoupleMutation
)

$ErrorActionPreference = "Stop"

$created = @{
  boyToken = $null
  girlToken = $null
  travelSpotId = $null
  travelPhotoId = $null
  todoId = $null
  financeId = $null
  courseId = $null
  timelineId = $null
  anniversaryId = $null
  rewardTodoId = $null
  rewardAnniversaryId = $null
  rewardTravelSpotId = $null
  coupleCreated = $false
}

function Write-Step([string]$Name) {
  Write-Host ""
  Write-Host "== $Name ==" -ForegroundColor Cyan
}

function Write-Pass([string]$Name) {
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

function Get-Field($Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $prop = $Object.PSObject.Properties[$Name]
  if ($null -eq $prop) { return $null }
  return $prop.Value
}

function Get-Data($Response) {
  $data = Get-Field $Response "data"
  if ($null -ne $data) { return $data }
  return $Response
}

function Get-FirstValue($Object, [string[]]$Names) {
  foreach ($name in $Names) {
    $value = Get-Field $Object $name
    if ($null -ne $value -and "$value" -ne "") { return $value }
  }
  return $null
}

function Get-ResponseId($Response) {
  $data = Get-Data $Response
  $id = Get-FirstValue $data @("id", "insertId", "insert_id")
  if ($null -ne $id) { return [int]$id }
  return $null
}

function Test-OkResponse($Response, [string]$Name) {
  if ($null -eq $Response) {
    throw "$Name returned empty response"
  }
  $code = Get-Field $Response "code"
  if ($null -ne $code -and [int]$code -ne 200) {
    $message = Get-Field $Response "message"
    throw "$Name returned code=$code message=$message"
  }
  Write-Pass $Name
}

function Invoke-LgApi(
  [string]$Method,
  [string]$Path,
  [object]$Body = $null,
  [string]$Token = $null,
  [int]$Timeout = $TimeoutSec
) {
  $uri = $BaseUrl.TrimEnd("/") + $Path
  $headers = @{}
  if ($Token) { $headers["Authorization"] = "Bearer $Token" }

  try {
    if ($null -ne $Body) {
      $json = $Body | ConvertTo-Json -Depth 20
      return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $json -ContentType "application/json; charset=utf-8" -TimeoutSec $Timeout
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -TimeoutSec $Timeout
  } catch {
    $detail = $_.Exception.Message
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
      $detail = "$detail $($_.ErrorDetails.Message)"
    }
    throw "$Method $Path failed: $detail"
  }
}

function Invoke-LgApiAllowStatus(
  [string]$Method,
  [string]$Path,
  [int[]]$AllowedStatus,
  [string]$Token = $null
) {
  $uri = $BaseUrl.TrimEnd("/") + $Path
  $headers = @{}
  if ($Token) { $headers["Authorization"] = "Bearer $Token" }

  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $uri -Headers $headers -TimeoutSec $TimeoutSec
    if ($AllowedStatus -notcontains [int]$resp.StatusCode) {
      throw "$Method $Path returned HTTP $($resp.StatusCode), expected $($AllowedStatus -join ",")"
    }
    return $resp.StatusCode
  } catch {
    $webResp = $_.Exception.Response
    if ($webResp -and $AllowedStatus -contains [int]$webResp.StatusCode) {
      return [int]$webResp.StatusCode
    }
    throw
  }
}

function Find-Token($Response) {
  $data = Get-Data $Response
  $token = Get-FirstValue $data @("token", "accessToken", "access_token", "jwt")
  if ($token) { return $token }
  $token = Get-FirstValue $Response @("token", "accessToken", "access_token", "jwt")
  if ($token) { return $token }
  throw "Login response did not contain token"
}

function Find-InviteCode($Response) {
  $data = Get-Data $Response
  $code = Get-FirstValue $data @("invite_code", "inviteCode", "code")
  if ($code) { return "$code" }
  throw "Invite response did not contain invite code"
}

function Get-List($Response) {
  $data = Get-Data $Response
  if ($data -is [System.Array]) { return $data }
  $list = Get-FirstValue $data @("list", "items", "records", "rows")
  if ($list -is [System.Array]) { return $list }
  return @()
}

function Test-Truthy($Value) {
  if ($null -eq $Value) { return $false }
  if ($Value -eq $true) { return $true }
  $text = "$Value"
  return $text -eq "1" -or $text.ToLowerInvariant() -eq "true"
}

function Upload-TravelPhoto([string]$Token, [int]$SpotId) {
  $pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
  $tmp = Join-Path $env:TEMP "$Prefix-travel-photo.png"
  [IO.File]::WriteAllBytes($tmp, [Convert]::FromBase64String($pngBase64))
  $uri = $BaseUrl.TrimEnd("/") + "/api/travel/spots/$SpotId/photos"
  $raw = & curl.exe -sS --max-time $TimeoutSec -H "Authorization: Bearer $Token" -F "photo=@$tmp;type=image/png" $uri
  if ($LASTEXITCODE -ne 0) {
    throw "travel photo upload curl failed with exit code $LASTEXITCODE"
  }
  $resp = $raw | ConvertFrom-Json
  Test-OkResponse $resp "travel photo upload"
  return Get-ResponseId $resp
}

function Cleanup {
  Write-Step "cleanup"
  if ($created.travelPhotoId -and $created.travelSpotId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/travel/spots/$($created.travelSpotId)/photos/$($created.travelPhotoId)" -Token $created.boyToken | Out-Null; Write-Pass "delete travel photo" } catch { Write-Warning $_ }
  }
  if ($created.travelSpotId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/travel/spots/$($created.travelSpotId)" -Token $created.boyToken | Out-Null; Write-Pass "delete travel spot" } catch { Write-Warning $_ }
  }
  if ($created.rewardTravelSpotId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/travel/spots/$($created.rewardTravelSpotId)" -Token $created.boyToken | Out-Null; Write-Pass "delete reward travel spot" } catch { Write-Warning $_ }
  }
  if ($created.todoId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/todo/$($created.todoId)" -Token $created.boyToken | Out-Null; Write-Pass "delete todo" } catch { Write-Warning $_ }
  }
  if ($created.financeId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/finance/$($created.financeId)" -Token $created.boyToken | Out-Null; Write-Pass "delete finance" } catch { Write-Warning $_ }
  }
  if ($created.courseId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/course/$($created.courseId)" -Token $created.boyToken | Out-Null; Write-Pass "delete course" } catch { Write-Warning $_ }
  }
  if ($created.timelineId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/timeline/$($created.timelineId)" -Token $created.boyToken | Out-Null; Write-Pass "delete timeline" } catch { Write-Warning $_ }
  }
  if ($created.anniversaryId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/anniversary/$($created.anniversaryId)" -Token $created.boyToken | Out-Null; Write-Pass "delete anniversary" } catch { Write-Warning $_ }
  }
  if ($created.rewardAnniversaryId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/anniversary/$($created.rewardAnniversaryId)" -Token $created.boyToken | Out-Null; Write-Pass "delete reward anniversary" } catch { Write-Warning $_ }
  }
  if ($created.rewardTodoId -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/todo/$($created.rewardTodoId)" -Token $created.boyToken | Out-Null; Write-Pass "delete reward todo" } catch { Write-Warning $_ }
  }
  if ($created.coupleCreated -and -not $PreserveCouple -and $created.boyToken) {
    try { Invoke-LgApi "DELETE" "/api/couple" -Token $created.boyToken | Out-Null; Write-Pass "break couple" } catch { Write-Warning $_ }
  }
}

Write-Host "LoveGirl non-UI release E2E acceptance"
Write-Host "BaseUrl: $BaseUrl"
Write-Host "Prefix:  $Prefix"

try {
  Write-Step "smoke"
  Test-OkResponse (Invoke-LgApi "GET" "/api/health") "GET /api/health"
  Test-OkResponse (Invoke-LgApi "GET" "/api/version/check?version_code=143") "GET /api/version/check"
  $status = Invoke-LgApiAllowStatus "GET" "/api/user/profile" @(401,403) -Token "invalid-token"
  Write-Pass "invalid token rejected with HTTP $status"

  if ($SkipWrites) {
    Write-Host "SkipWrites was set; smoke checks completed."
    exit 0
  }

  $usingExistingAccounts = $UseExistingAccounts -or (
    $BoyUsername -and $BoyPassword -and $GirlUsername -and $GirlPassword
  )
  if ($usingExistingAccounts -and (-not $BoyUsername -or -not $BoyPassword -or -not $GirlUsername -or -not $GirlPassword)) {
    throw "UseExistingAccounts requires BoyUsername, BoyPassword, GirlUsername, and GirlPassword"
  }

  $boyUsername = if ($usingExistingAccounts) { $BoyUsername } else { ("e2e_boy_" + $Prefix).ToLowerInvariant() }
  $boyPassword = if ($usingExistingAccounts) { $BoyPassword } else { $Password }
  $girlUsername = if ($usingExistingAccounts) { $GirlUsername } else { ("e2e_girl_" + $Prefix).ToLowerInvariant() }
  $girlPassword = if ($usingExistingAccounts) { $GirlPassword } else { $Password }
  $today = Get-Date -Format "yyyy-MM-dd"
  $month = Get-Date -Format "yyyy-MM"

  Write-Step "auth and couple"
  if ($usingExistingAccounts) {
    Write-Host "Using existing paired accounts; couple binding will be preserved."
    $PreserveCouple = $true
  } else {
    Test-OkResponse (Invoke-LgApi "POST" "/api/auth/register" @{
      username = $boyUsername
      password = $boyPassword
      nickname = "$Prefix boy"
      gender = "male"
    }) "register boy"
    Test-OkResponse (Invoke-LgApi "POST" "/api/auth/register" @{
      username = $girlUsername
      password = $girlPassword
      nickname = "$Prefix girl"
      gender = "female"
    }) "register girl"
  }
  $created.boyToken = Find-Token (Invoke-LgApi "POST" "/api/auth/login" @{ username = $boyUsername; password = $boyPassword })
  Write-Pass "login boy"
  $created.girlToken = Find-Token (Invoke-LgApi "POST" "/api/auth/login" @{ username = $girlUsername; password = $girlPassword })
  Write-Pass "login girl"
  Test-OkResponse (Invoke-LgApi "GET" "/api/user/profile" -Token $created.boyToken) "boy profile"
  Test-OkResponse (Invoke-LgApi "GET" "/api/user/profile" -Token $created.girlToken) "girl profile"
  if ($usingExistingAccounts) {
    $boyCoupleResp = Invoke-LgApi "GET" "/api/couple" -Token $created.boyToken
    Test-OkResponse $boyCoupleResp "boy couple status"
    $girlCoupleResp = Invoke-LgApi "GET" "/api/couple" -Token $created.girlToken
    Test-OkResponse $girlCoupleResp "girl couple status"
    $boyCoupled = Test-Truthy (Get-Field (Get-Data $boyCoupleResp) "coupled")
    $girlCoupled = Test-Truthy (Get-Field (Get-Data $girlCoupleResp) "coupled")
    if (-not $boyCoupled -or -not $girlCoupled) {
      if (-not $AllowExistingCoupleMutation) {
        throw "Existing accounts are not coupled; pass AllowExistingCoupleMutation for dedicated test accounts or run against an empty/staging database"
      }
      $inviteCode = Find-InviteCode (Invoke-LgApi "POST" "/api/couple/invite" -Token $created.boyToken)
      Write-Pass "create couple invite for existing accounts"
      Test-OkResponse (Invoke-LgApi "POST" "/api/couple/accept" @{ code = $inviteCode } -Token $created.girlToken) "accept couple invite for existing accounts"
    }
  } else {
    $inviteCode = Find-InviteCode (Invoke-LgApi "POST" "/api/couple/invite" -Token $created.boyToken)
    Write-Pass "create couple invite"
    Test-OkResponse (Invoke-LgApi "POST" "/api/couple/accept" @{ code = $inviteCode } -Token $created.girlToken) "accept couple invite"
    $created.coupleCreated = $true
    Test-OkResponse (Invoke-LgApi "GET" "/api/couple" -Token $created.boyToken) "boy couple status"
    Test-OkResponse (Invoke-LgApi "GET" "/api/couple" -Token $created.girlToken) "girl couple status"
  }

  Write-Step "feeding"
  $shopsResp = Invoke-LgApi "GET" "/api/feeding/shops" -Token $created.boyToken
  Test-OkResponse $shopsResp "feeding shops"
  $shop = (Get-List $shopsResp)[0]
  if ($null -eq $shop) { throw "feeding shops returned empty list" }
  $shopId = [int](Get-Field $shop "id")
  $productsResp = Invoke-LgApi "GET" "/api/feeding/shops/$shopId/products" -Token $created.boyToken
  Test-OkResponse $productsResp "feeding products"
  $product = (Get-List $productsResp)[0]
  if ($null -eq $product) { throw "feeding products returned empty list" }
  $productId = [int](Get-Field $product "id")
  $productPrice = [int](Get-Field $product "price")
  $balanceResp = Invoke-LgApi "GET" "/api/beans/balance" -Token $created.boyToken
  $balance = [int](Get-FirstValue (Get-Data $balanceResp) @("balance", "bean_balance"))
  if ($balance -lt $productPrice) {
    Write-Step "bean earning setup"
    Test-OkResponse (Invoke-LgApi "POST" "/api/beans/checkin" -Token $created.boyToken) "daily bean checkin"
    $rewardTodoResp = Invoke-LgApi "POST" "/api/todo" @{ title = "$Prefix reward todo"; dueDate = $today } -Token $created.boyToken
    Test-OkResponse $rewardTodoResp "reward todo create"
    $created.rewardTodoId = Get-ResponseId $rewardTodoResp
    if ($created.rewardTodoId) { Test-OkResponse (Invoke-LgApi "PUT" "/api/todo/$($created.rewardTodoId)/toggle" -Token $created.boyToken) "reward todo complete" }
    Test-OkResponse (Invoke-LgApi "POST" "/api/mood" @{
      date = $today
      emoji = "5"
      label = "Ready"
      note = "$Prefix reward mood"
    } -Token $created.boyToken) "reward mood record"
    $rewardAnnResp = Invoke-LgApi "POST" "/api/anniversary" @{
      title = "$Prefix reward anniversary"
      description = "$Prefix reward anniversary description"
      type = "custom"
      eventDate = $today
      icon = "*"
      is_lunar = $false
      repeat_type = 0
    } -Token $created.boyToken
    Test-OkResponse $rewardAnnResp "reward anniversary create"
    $created.rewardAnniversaryId = Get-ResponseId $rewardAnnResp
    $rewardTravelResp = Invoke-LgApi "POST" "/api/travel/spots" @{
      name = "$Prefix reward checkin"
      city = "Hangzhou"
      address = "$Prefix reward address"
      lng = 120.1551
      lat = 30.2741
      status = "visited"
      note = "$Prefix reward travel"
      visitedDate = $today
      tags = @("e2e", "reward")
    } -Token $created.boyToken
    Test-OkResponse $rewardTravelResp "reward travel checkin"
    $created.rewardTravelSpotId = Get-ResponseId $rewardTravelResp
    $balanceResp = Invoke-LgApi "GET" "/api/beans/balance" -Token $created.boyToken
    $balance = [int](Get-FirstValue (Get-Data $balanceResp) @("balance", "bean_balance"))
    if ($balance -lt $productPrice) {
      throw "bean earning setup produced balance=$balance but product price=$productPrice"
    }
  }
  $orderResp = Invoke-LgApi "POST" "/api/feeding/orders" @{
    product_id = $productId
    shop_id = $shopId
    quantity = 1
    message = "$Prefix feeding order"
  } -Token $created.boyToken
  Test-OkResponse $orderResp "feeding create order"
  $orderId = Get-ResponseId $orderResp
  if (-not $orderId) { throw "feeding create order did not return id" }
  Test-OkResponse (Invoke-LgApi "POST" "/api/feeding/orders/$orderId/urge" -Token $created.boyToken) "feeding urge"
  foreach ($next in @("accepted", "preparing", "delivering", "completed")) {
    Test-OkResponse (Invoke-LgApi "PUT" "/api/feeding/orders/$orderId/status" @{ status = $next } -Token $created.girlToken) "feeding status $next"
  }
  Test-OkResponse (Invoke-LgApi "GET" "/api/feeding/orders" -Token $created.boyToken) "feeding orders"
  Test-OkResponse (Invoke-LgApi "GET" "/api/feeding/stats" -Token $created.boyToken) "feeding stats"

  Write-Step "travel and timeline"
  $spotResp = Invoke-LgApi "POST" "/api/travel/spots" @{
    name = "$Prefix travel spot"
    city = "Hangzhou"
    address = "$Prefix address"
    lng = 120.1551
    lat = 30.2741
    status = "wish"
    note = "$Prefix note"
    tags = @("e2e")
  } -Token $created.boyToken
  Test-OkResponse $spotResp "travel create spot"
  $created.travelSpotId = Get-ResponseId $spotResp
  if (-not $created.travelSpotId) { throw "travel create spot did not return id" }
  Test-OkResponse (Invoke-LgApi "GET" "/api/travel/spots/$($created.travelSpotId)" -Token $created.girlToken) "travel partner can read spot"
  Test-OkResponse (Invoke-LgApi "PUT" "/api/travel/spots/$($created.travelSpotId)" @{
    name = "$Prefix travel spot updated"
    city = "Hangzhou"
    address = "$Prefix address"
    lng = 120.1551
    lat = 30.2741
    status = "visited"
    note = "$Prefix updated note"
    tags = @("e2e", "updated")
  } -Token $created.boyToken) "travel update spot"
  $created.travelPhotoId = Upload-TravelPhoto $created.boyToken $created.travelSpotId
  Test-OkResponse (Invoke-LgApi "GET" "/api/travel/spots/$($created.travelSpotId)/photos" -Token $created.girlToken) "travel photos list"
  $timelineResp = Invoke-LgApi "POST" "/api/timeline" @{
    title = "$Prefix timeline"
    description = "$Prefix timeline description"
    eventDate = $today
    icon = "travel"
  } -Token $created.boyToken
  Test-OkResponse $timelineResp "timeline create"
  $created.timelineId = Get-ResponseId $timelineResp
  Test-OkResponse (Invoke-LgApi "GET" "/api/timeline" -Token $created.girlToken) "timeline list"

  Write-Step "chat"
  Test-OkResponse (Invoke-LgApi "POST" "/api/chat" @{ content = "$Prefix hello from boy" } -Token $created.boyToken) "chat send boy"
  Test-OkResponse (Invoke-LgApi "POST" "/api/chat" @{ content = "$Prefix hello from girl" } -Token $created.girlToken) "chat send girl"
  Test-OkResponse (Invoke-LgApi "GET" "/api/chat?page=1&size=20" -Token $created.boyToken) "chat page"
  Test-OkResponse (Invoke-LgApi "GET" "/api/chat/unread" -Token $created.girlToken) "chat unread"

  Write-Step "period"
  Test-OkResponse (Invoke-LgApi "POST" "/api/period" @{ start_date = $today } -Token $created.girlToken) "period start"
  Test-OkResponse (Invoke-LgApi "GET" "/api/period/status" -Token $created.girlToken) "period status"
  Test-OkResponse (Invoke-LgApi "POST" "/api/period" @{ end_date = $today } -Token $created.girlToken) "period end"
  Test-OkResponse (Invoke-LgApi "GET" "/api/period/analysis" -Token $created.girlToken) "period analysis"

  Write-Step "life modules"
  $todoResp = Invoke-LgApi "POST" "/api/todo" @{ title = "$Prefix todo"; dueDate = $today } -Token $created.boyToken
  Test-OkResponse $todoResp "todo create"
  $created.todoId = Get-ResponseId $todoResp
  Test-OkResponse (Invoke-LgApi "GET" "/api/todo" -Token $created.boyToken) "todo list"
  if ($created.todoId) { Test-OkResponse (Invoke-LgApi "PUT" "/api/todo/$($created.todoId)/toggle" -Token $created.boyToken) "todo toggle" }

  $financeResp = Invoke-LgApi "POST" "/api/finance" @{
    type = "expense"
    category = "E2E"
    amount = 1.23
    recordDate = $today
    description = "$Prefix finance"
  } -Token $created.boyToken
  Test-OkResponse $financeResp "finance create"
  $created.financeId = Get-ResponseId $financeResp
  Test-OkResponse (Invoke-LgApi "GET" "/api/finance?month=$month" -Token $created.boyToken) "finance list"
  Test-OkResponse (Invoke-LgApi "GET" "/api/finance/stats?month=$month" -Token $created.boyToken) "finance stats"

  $courseResp = Invoke-LgApi "POST" "/api/course" @{
    courseName = "$Prefix course"
    teacher = "E2E"
    classroom = "E2E room"
    dayOfWeek = 1
    startTime = "08:00"
    endTime = "08:45"
    weekType = "every"
    startWeek = 1
    endWeek = 20
    color = "#FF6B8A"
  } -Token $created.boyToken
  Test-OkResponse $courseResp "course create"
  $created.courseId = Get-ResponseId $courseResp
  Test-OkResponse (Invoke-LgApi "GET" "/api/course?term=E2E" -Token $created.boyToken) "course list"

  Write-Step "mood anniversary beans privacy"
  Test-OkResponse (Invoke-LgApi "POST" "/api/mood" @{
    date = $today
    emoji = "4"
    label = "E2E"
    note = "$Prefix mood"
  } -Token $created.girlToken) "mood record"
  Test-OkResponse (Invoke-LgApi "GET" "/api/mood?month=$month" -Token $created.girlToken) "mood list"
  Test-OkResponse (Invoke-LgApi "GET" "/api/mood/stats?month=$month" -Token $created.girlToken) "mood stats"

  $annResp = Invoke-LgApi "POST" "/api/anniversary" @{
    title = "$Prefix anniversary"
    description = "$Prefix anniversary description"
    type = "custom"
    eventDate = $today
    icon = "*"
    is_lunar = $false
    repeat_type = 0
  } -Token $created.boyToken
  Test-OkResponse $annResp "anniversary create"
  $created.anniversaryId = Get-ResponseId $annResp
  Test-OkResponse (Invoke-LgApi "GET" "/api/anniversary" -Token $created.girlToken) "anniversary list"
  Test-OkResponse (Invoke-LgApi "GET" "/api/beans/balance" -Token $created.boyToken) "beans balance"
  Test-OkResponse (Invoke-LgApi "GET" "/api/beans/transactions?page=1&size=20" -Token $created.boyToken) "beans transactions"
  Test-OkResponse (Invoke-LgApi "GET" "/api/privacy" -Token $created.boyToken) "privacy get"

  Cleanup
  Write-Host ""
  Write-Host "ALL CORE NON-UI E2E CHECKS PASSED" -ForegroundColor Green
  exit 0
} catch {
  Write-Host ""
  Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
  try { Cleanup } catch {}
  exit 1
}
