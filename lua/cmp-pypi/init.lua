local source = {}

---@return string
function source:get_debug_name()
	return "pypi"
end

---@return boolean
function source:is_available()
	local filename = vim.fn.expand("%:t")
	return filename == "pyproject.toml"
end

---@return string
function source:get_keyword_pattern()
	return [[\k\+]]
end

---@return string[]
function source:get_trigger_characters()
	return {
        -- Part way through a version
        ".", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        -- Case 1
        "=", " ",
        -- Case 2
        "^", "~", "\"",
    }
end

---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
	local core = require("cmp-pypi.core")

	local line = params.context.cursor_before_line

	if not core.should_complete() then
		return callback()
	end

	-- `package == version` for 0 to any number of spaces
	local name, _ = string.match(line, '([%w_%-]+)%s*==%s*([^"= ]*)$')

	if not name then
		-- `package = "version"` for 0 to any number of spaces
		name, _ = string.match(line, '^([%w_%-]+)%s*=%s*"([^"]*)$')

		if not name then
			return callback()
		end
	end

	vim.schedule(function()
		local result = core.complete(name)
		callback(result)
	end)
end

---@param completion_item lsp.CompletionItem
---@param callback function
function source:resolve(completion_item, callback)
	callback(completion_item)
end

---@param completion_item lsp.CompletionItem
---@param callback function
function source:execute(completion_item, callback)
	callback(completion_item)
end

return source
