

SELECT *
FROM CovidDataProject..NashVilleHousing

-- Standardize Date Format

SELECT SaleDateConverted, convert(Date, SaleDate)
FROM CovidDataProject..NashVilleHousing

UPDATE NashVilleHousing
SET SaleDate = convert(Date, SaleDate)

ALTER TABLE NashVilleHousing
ADD SaleDateConverted Date;

UPDATE NashVilleHousing
SET SaleDateConverted = convert(Date, SaleDate)

-- Populate Property Address

SELECT *
FROM CovidDataProject..NashVilleHousing
--WHERE PropertyAddress is null
ORDER BY ParcelID

SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, isnull(a.PropertyAddress, b.PropertyAddress)
FROM CovidDataProject..NashVilleHousing a
JOIN CovidDataProject..NashVilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress is null

UPDATE a
SET PropertyAddress = isnull(a.PropertyAddress, b.PropertyAddress)
FROM CovidDataProject..NashVilleHousing a
JOIN CovidDataProject..NashVilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress is null

-- Breaking the address into parts

SELECT PropertyAddress
FROM CovidDataProject..NashVilleHousing
--ORDER BY SaleDate

SELECT SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1) as Address, 
SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress)) as Address
FROM CovidDataProject..NashVilleHousing

ALTER TABLE NashVilleHousing
ADD PropSplitAddress nvarchar(255);

UPDATE NashVilleHousing
SET PropSplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1);

ALTER TABLE NashVilleHousing
ADD PropSplitCity nvarchar(255);

UPDATE NashVilleHousing
SET PropSplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress))

-- Populate Owner Address

SELECT OwnerAddress
FROM CovidDataProject..NashVilleHousing

SELECT PARSENAME(replace(OwnerAddress, ',', '.'), 3),
PARSENAME(replace(OwnerAddress, ',', '.'), 2),
PARSENAME(replace(OwnerAddress, ',', '.'), 1)
FROM CovidDataProject..NashVilleHousing

ALTER TABLE NashVilleHousing
ADD OwnerSplitAddress nvarchar(255);

UPDATE NashVilleHousing
SET OwnerSplitAddress = PARSENAME(replace(OwnerAddress, ',', '.'), 3);

ALTER TABLE NashVilleHousing
ADD OwnerSplitCity nvarchar(255);

UPDATE NashVilleHousing
SET OwnerSplitCity = PARSENAME(replace(OwnerAddress, ',', '.'), 2);

ALTER TABLE NashVilleHousing
ADD OwnerSplitState nvarchar(255);

UPDATE NashVilleHousing
SET OwnerSplitState = PARSENAME(replace(OwnerAddress, ',', '.'), 1);

-- Change Y/N to Yes/No in SoldAsVacant

SELECT Distinct(SoldAsVacant), Count(SoldAsVacant)
FROM CovidDataProject..NashVilleHousing
GROUP BY SoldAsVacant
ORDER BY 2

SELECT SoldAsVacant,
CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	 WHEN SoldAsVacant = 'N' THEN 'No'
	 ELSE SoldAsVacant
	 END as Revised
FROM CovidDataProject..NashVilleHousing

UPDATE NashVilleHousing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	 WHEN SoldAsVacant = 'N' THEN 'No'
	 ELSE SoldAsVacant
	 END

-- Deleting Duplicates

WITH RowNumCTE as (
SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference
	ORDER BY UniqueID
	) row_num
FROM CovidDataProject..NashVilleHousing
)
DELETE 
FROM RowNumCTE
WHERE row_num > 1
--ORDER BY ParcelID

-- Delete Unused Columns

ALTER TABLE CovidDataProject..NashVilleHousing
DROP COLUMN TaxDistrict, OwnerAddress, PropertyAddress, SaleDate

SELECT *
FROM CovidDataProject..NashVilleHousing