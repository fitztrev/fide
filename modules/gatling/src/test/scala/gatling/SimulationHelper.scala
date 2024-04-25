package fide.gatling

import io.gatling.core.Predef.*
import io.gatling.core.controller.inject.open.OpenInjectionStep
import io.gatling.http.Predef.*
import scala.concurrent.duration.DurationInt

object SimulationHelper:

  val httpProtocol = http.baseUrl(config.serverUri)

  def defaultPlayers(page: Int): String =
    s"/players?page=$page"

  def sortByStandard(page: Int): String =
    s"/players?sort_by=standard&order=desc&page=$page"

  def federationSummary(page: Int): String =
    s"/federations/summary?page=$page"

  def requests(page: Int, name: String, f: Int => String) =
    Range.inclusive(1, page).map(f).map(http(name).get(_).check(status.is(200)))

// Add the ScenarioBuilder:
  def makeScenario(page: Int, name: String) = scenario(name)
    .exec(requests(page, "default-players", defaultPlayers))
    .exec(requests(page, "standard-players", sortByStandard))
    .exec(requests(page, "federation-summary", federationSummary))

  object config:
    val numberOfUsers = 1000
    val maxPages      = 10

    val serverUri = "http://localhost:9669/api"

    val stressPolicy: OpenInjectionStep = rampUsers(numberOfUsers).during(30.seconds)
