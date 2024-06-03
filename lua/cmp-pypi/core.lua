---@param node TSNode|nil
---@param buf integer
---@returns boolean
local function is_correct_node(node, buf)
	if node == nil then
		return
	end

	if node:type() ~= "string" then
		return
	end

	node = node:parent()

	if node:type() ~= "array" and node:type() ~= "pair" then
		return
	end

	if node:type() == "array" then
		node = node:parent()

		if node:type() ~= "pair" then
			return
		end

		node = node:named_child()

		if node == nil then
			return
		end

		local key_text = vim.treesitter.get_node_text(node, buf)
		if key_text ~= "dependencies" then
			return
		end
	else
		node = node:parent()

		if node:type() ~= "table" then
			return
		end

		if not string.find(vim.treesitter.get_node_text(node, buf), "dependencies") then
			return
		end
	end

	return true
end

---@param node TSNode|nil
---@param buf integer
---@returns boolean
local function has_correct_string(node, buf)
	if node == nil then
		return
	end

	local string_text = vim.treesitter.get_node_text(node, buf)
	if not string_text:match('=="$') then
		return
	end

	-- vim.treesitter.
	return true
end

local function should_complete()
	local node = vim.treesitter.get_node()
	local buf = vim.api.nvim_get_current_buf()
	return is_correct_node(node, buf)
	-- return is_correct_node(node, buf) and has_correct_string(node, buf)
end

---@type { [string]: lsp.CompletionResponse|nil }
local cmp_cache = {}

local function sorted_iter_by_key(t)
	local i = {}
	for k in next, t do
		table.insert(i, k)
	end
	table.sort(i)
	return function()
		return table.remove(i)
	end
end

---@name string|nil
---@returns lsp.CompletionResponse|nil
local function complete(name)
	if cmp_cache[name] then
		return cmp_cache[name]
	end

	local response = require("plenary.curl").get(
		("https://pypi.org/pypi/%s/json"):format(name),
		{ headers = {
			content_type = "application/json",
		} }
	)

	local res_json = vim.fn.json_decode(response.body)
	if res_json == nil or res_json.releases == nil then
		return
	end

	local result = {}
	local i = 0
	for version in sorted_iter_by_key(res_json.releases) do
		table.insert(result, { label = version, sortText = string.format("%04d", i) })
		i = i + 1
	end

	cmp_cache[name] = result
	return result
end

return {
	should_complete = should_complete,
	complete = complete,
}
