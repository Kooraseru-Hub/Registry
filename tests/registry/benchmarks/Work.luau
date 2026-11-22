--!strict

const kind = script:GetAttribute("Kind")
const steps = script:GetAttribute("Steps")
if type(steps) ~= "number" then
	return 1
end

local sum = 1
if kind == "arithmetic" then
	for index = 1, steps do
		sum += index
	end
else
	const values: { number } = table.create(steps, 0)
	for index = 1, steps do
		values[index] = index
		sum += if kind == "mixed" then values[index] * index else values[index]
	end
end
return sum
