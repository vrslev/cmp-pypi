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
    --                  OR
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

local function should_complete()
	local node = vim.treesitter.get_node()
	local buf = vim.api.nvim_get_current_buf()
	return is_correct_node(node, buf)
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
