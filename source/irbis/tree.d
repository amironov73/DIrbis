/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.tree;

import std.algorithm: canFind, remove;
import std.array;
import std.bitmanip;
import std.conv;
import std.encoding: transcode, Windows1251String;
import std.random: uniform;
import std.socket;
import std.stdio;
import std.string;
import std.outbuffer;

//==================================================================

/**
 * Node of TRE-file.
 */
export final class TreeNode
{
    TreeNode[] children; /// Slice of children.
    string value; /// Value of the node.
    int level; /// Level of the node.

    /**
     * Constructor.
     */
    this(string value="")
    {
        this.value = value;
    } // constructor

    /**
     * Add child node with specified value.
     */
    TreeNode add(string value)
    {
        auto child = new TreeNode(value);
        child.level = this.level + 1;
        children ~= child;
        return this;
    } // method add

    pure override string toString() const
    {
        return value;
    } // method toString

} // class TreeNode

//==================================================================

/**
 * TRE-file.
 */
export final class TreeFile
{
    TreeNode[] roots; /// Slice of root nodes.

    private static void arrange1(TreeNode[] list, int level)
    {
        int count = cast(int)list.length;
        auto index = 0;
        while (index < count)
        {
            const next = arrange2(list, level, index, count);
            index = next;
        }
    } // method arrange1

    private static int arrange2(TreeNode[] list, int level, int index, int count)
    {
        int next = index + 1;
        const level2 = level + 1;
        auto parent = list[index];
        while (next < count)
        {
            auto child = list[next];
            if (child.level < level)
                break;
            if (child.level == level2)
                parent.children ~= child;
            next++;
        }

        return next;
    } // method arrange2

    private static int countIndent(string text)
    {
        auto result = 0;
        const length = text.length;
        for (int i = 0; i < length; i++)
            if (text[i] == '\t')
                result++;
            else
                break;
        return result;
    } // method countIndent

    /**
     * Add root node.
     */
    TreeFile addRoot(string value)
    {
        auto root = new TreeNode(value);
        roots ~= root;
        return this;
    } // method addRoot

    /**
     * Parse the text representation.
     */
    void parse(string[] lines)
    {
        if (lines.length == 0)
            return;

        TreeNode[] list = [];
        int currentLevel = 0;
        auto firstLine = lines[0];
        if (firstLine.empty || (countIndent(firstLine) != 0))
            throw new Exception("Wrong TRE");

        list ~= new TreeNode(firstLine);
        foreach (line; lines)
        {
            if (line.empty)
                continue;

            auto level = countIndent(line);
            if (level > (currentLevel + 1))
                throw new Exception("Wrong TRE");

            currentLevel = level;
            auto node = new TreeNode(line[level..$]);
            node.level = level;
            list ~= node;
        } // foreach

        int maxLevel = 0;
        foreach (item; list)
            if (item.level > maxLevel)
                maxLevel = item.level;

        for (int level = 0; level < maxLevel; level++)
            arrange1(list, level);

        foreach (item; list)
            if (item.level == 0)
                roots ~= item;
    } // method parse

} // class TreeFile

