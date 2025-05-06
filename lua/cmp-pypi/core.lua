local PriorityQueue = require("cmp-pypi.priority_queue")

---@param node TSNode|nil
---@param buf integer
---@returns boolean
local function is_correct_node(node, buf)
	if node == nil then
		return false
	end

	-- Case 1:
	-- | [project]
	-- | dependencies = [
	-- |     "<package> *== *<version>",
	-- | ]
	--             OR
	-- | [project.optional-dependencies]
	-- | my-extras = [
	-- |     "<package> *== *<version>",
	-- | ]
	-- This also catches when the "<package> *== *<version>" string is not closed
	repeat
		if node:type() ~= "string" and node:type() ~= "ERROR" then
			break
		end

		local parent = node:parent()
		if parent:type() ~= "array" then
			break
		end

		local grandparent = parent:parent()
		if grandparent:type() ~= "pair" then
			break
		end
		local grandparent_name = vim.treesitter.get_node_text(grandparent:named_child(), buf)

		local greatgrandparent = grandparent:parent()
		if greatgrandparent:type() ~= "table" then
			break
		end
		local greatgrandparent_name = vim.treesitter.get_node_text(greatgrandparent:named_child(), buf)

		if not string.find(greatgrandparent_name, "project") then
			break
		end
		if not string.find(grandparent_name, "dependencies") then
			if not string.find(greatgrandparent_name, "dependencies") then
				break
			end
		end

		return true
	until true

	-- Case 2:
	-- | [table.name.containing.dependencies]
	-- | <package> *= *"<version>"
	-- This also catches when the "<version>" string is not closed
	repeat
		if node:type() == "ERROR" then

			local last_sibling = node:prev_sibling()
			if last_sibling:type() ~= "table" then
				break
			end
			local last_sibling_name = vim.treesitter.get_node_text(last_sibling:named_child(), buf)
			if not string.find(last_sibling_name, "dependencies") then
				break
			end

			return true

		end

		if node:type() ~= "string" then
			break
		end

		local parent = node:parent()
		if parent:type() ~= "pair" then
			break
		end

		local grandparent = parent:parent()
		if grandparent:type() ~= "table" then
			break
		end
		local grandparent_name = vim.treesitter.get_node_text(grandparent:named_child(), buf)
		if not string.find(grandparent_name, "dependencies") then
			break
		end

		return true
	until true

	return false
end

local function parse_python_version(str, offset)
	local ret = nil
	str = str:gsub("%s+", "")
	if str:find(">=") ~= nil and str:find(",") == nil then
		local separator_start, _ = str:find("%.")
		ret = {}
		ret["major"] = tonumber(str:sub(3 + offset, separator_start - 1))
		ret["minor"] = tonumber(str:sub(separator_start + 1, -1 - offset))
	end
	return ret
end

local function parse_pyproject_python_version(str)
	return parse_python_version(str, 1)
end

local function parse_pypi_package_python_version(str)
	return parse_python_version(str, 0)
end

---@type { [string]: lsp.CompletionResponse|nil }
local var_cache = {}

local function get_requires_python(node, buf)
	if var_cache["requires-python"] then
		return var_cache["requires-python"]
	end
	local tree_root = node:tree():root()
	local python_version_query = vim.treesitter.query.parse("toml", [[
		(document
		  (table
			(pair
			  (bare_key) @key-name (#eq? @key-name "requires-python")
			  (string) @value
			)
		  )
		)
	]])
	for id, requires_node, _ in python_version_query:iter_captures(tree_root, buf) do
		if id == 2 then
			local raw_text = vim.treesitter.get_node_text(requires_node, buf)
			var_cache["requires-python"] = parse_pyproject_python_version(raw_text)
		end
	end
	return var_cache["requires-python"]
end

---@type { [string]: lsp.CompletionResponse|nil }
local cmp_cache = {}

local function versions_sorted_by_upload_date_descending(releases, node, buf)
	local pq = PriorityQueue("max")

	for version, releases_list in pairs(releases) do
		if type(releases_list) == "table" then
			for _, release_info in ipairs(releases_list) do
				if type(release_info) == "table" and release_info.upload_time_iso_8601 then
					local package_python = nil
					if release_info.requires_python and release_info.requires_python ~= vim.NIL then
						package_python = parse_pypi_package_python_version(release_info.requires_python)
					end
					local skip = false
					skip = skip or release_info.yanked
					local requires_python = get_requires_python(node, buf)
					skip = skip or (
						package_python ~= nil
						and requires_python ~= nil
						and (
							package_python.major > requires_python.major
							or (
								package_python.major == requires_python.major
								and package_python.minor > requires_python.minor
							)
						)
					)
					if not skip then
						pq:enqueue(version, release_info.upload_time_iso_8601)
						break
					end
				end
			end
		end
	end

	return pq
end

---@name string|nil
---@returns lsp.CompletionResponse|nil
local function complete(name, node, buf)
	if cmp_cache[name] then
		return cmp_cache[name]
	end

	local response = require("plenary.curl").get(
		("https://pypi.org/pypi/%s/json"):format(name),
		{
			headers = {
				content_type = "application/json",
			},
		}
	)

	local res_json = vim.fn.json_decode(response.body)
	if res_json == nil or res_json.releases == nil or type(res_json.releases) ~= "table" then
		return
	end

	local versions_by_date = versions_sorted_by_upload_date_descending(res_json.releases, node, buf)

	local result = {}
	for i = 1, #versions_by_date do
		local version = versions_by_date:dequeue()
		table.insert(result, { label = version, sortText = string.format("%04d", i) })
	end

	cmp_cache[name] = result
	return result
end

return {
	complete = complete,
	get_requires_python = get_requires_python,
	is_correct_node = is_correct_node,
}
