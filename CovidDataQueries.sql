SELECT * FROM CovidDataProject..CovidDeaths
ORDER BY 3,4

SELECT * FROM CovidDataProject..CovidVaccinations
ORDER BY 3,4

SELECT location, date, total_cases, new_cases, total_deaths, population 
FROM CovidDataProject..CovidDeaths
WHERE continent is not null
ORDER BY 1, 2

-- Looking at Total Cases vs Total Deaths
-- Likelihood of dying after contacting covid in India
SELECT location, date, total_cases, total_deaths, (ISNULL(cast(total_deaths as numeric), 0)/cast(total_cases as numeric))*100 as DeathPercentage
FROM CovidDataProject..CovidDeaths
WHERE continent is not null
-- WHERE location = 'India'
ORDER BY 1, 2

-- Looking at Total Cases vs Population
-- what percentage of people contacted covid
SELECT location, date, population, total_cases, ISNULL(cast(total_cases as numeric), 0) / cast(population as numeric)*100 as InfectionRate
FROM CovidDataProject..CovidDeaths
WHERE continent is not null
-- WHERE location = 'India'
ORDER BY 1, 2

-- Looking at countries with highest infection rate compared to population

SELECT location, population, 
max(total_cases) as HighestCase,
max(cast(total_cases as numeric)) / cast(population as numeric) *100 as InfectionRate
FROM CovidDataProject..CovidDeaths
WHERE continent is not null
GROUP BY location, population
ORDER BY InfectionRate desc

-- Showing continents with highest death count

SELECT continent, max(cast(total_cases as numeric)) as HighestDeaths
FROM CovidDataProject..CovidDeaths
WHERE continent is not null
GROUP BY continent
ORDER BY HighestDeaths desc

-- Global death percentage

SELECT sum(new_cases) as total_cases, sum(new_deaths) as total_deaths, sum(cast(new_deaths as numeric))/nullif(sum(cast(new_cases as numeric)), 0)*100 as GlobalDeathPercentage
FROM CovidDataProject..CovidDeaths
WHERE continent is not null
--GROUP BY date
ORDER BY 1, 2

-- Looking at Total population vs Vaccinations

SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations, 
	sum(convert(float, vacc.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) as RollingPeopleVaccinated
FROM CovidDataProject..CovidDeaths dea
JOIN CovidDataProject..CovidVaccinations vacc
	ON dea.location = vacc.location
	and dea.date = vacc.date
WHERE dea.continent is not null
ORDER BY 2,3

-- Use CTE

WITH PopvsVacc (Continent, location, date, population, new_vaccinations, RollingPeopleVaccinated)
AS 
(
SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations, 
	sum(convert(float, vacc.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) as RollingPeopleVaccinated
FROM CovidDataProject..CovidDeaths dea
JOIN CovidDataProject..CovidVaccinations vacc
	ON dea.location = vacc.location
	and dea.date = vacc.date
WHERE dea.continent is not null
--ORDER BY 2,3
)
SELECT *, (RollingPeopleVaccinated/population)*100
FROM PopvsVacc

-- TEMP TABLE

DROP TABLE IF EXISTS #PercentPopVaccinated
CREATE TABLE #PercentPopVaccinated (
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
new_vaccinations numeric,
RollingPeopleVaccinated numeric
)
INSERT INTO #PercentPopVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations, 
	sum(convert(float, vacc.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) as RollingPeopleVaccinated
FROM CovidDataProject..CovidDeaths dea
JOIN CovidDataProject..CovidVaccinations vacc
	ON dea.location = vacc.location
	and dea.date = vacc.date
-- WHERE dea.continent is not null
-- ORDER BY 2,3

SELECT *, (RollingPeopleVaccinated/population)*100
FROM #PercentPopVaccinated

-- Creating Views to store data for later use

CREATE VIEW PercentPopVaccinated as
SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations, 
	sum(convert(float, vacc.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) as RollingPeopleVaccinated
FROM CovidDataProject..CovidDeaths dea
JOIN CovidDataProject..CovidVaccinations vacc
	ON dea.location = vacc.location
	and dea.date = vacc.date
WHERE dea.continent is not null
--ORDER BY 2,3

SELECT * FROM PercentPopVaccinated